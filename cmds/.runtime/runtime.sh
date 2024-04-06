#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

if [ "$(lsb_release -is)" != "Debian" ] || [ "$(lsb_release -rs)" != "12" ]; then
  echo "This script is only supported on Debian 12"
  exit 1
fi

# shellcheck source=base.sh
. base.sh
# shellcheck source=../../.env.sh
. "$PWD/.env.sh"

dynamic_conn_string="db_connection"
# The list of variables that are expected to be set at runtime.
# The format is "name#description".
runtime_expectations=(
  # variables
  "repo_dir#The directory of the repository."
  # functions
  "fn_fail_on_used_port#A function that fails if a port is already in use."
  "fn_print_line#A function that prints a line the width of the user's terminal. Useful for displaying some forms of data."
  "fn_arg_info#A function whose first argument is the aliased name of a script and second argument is the description of the script. Automatically supplied the information to the output when the user includes a --help flag."
  "fn_arg_accept#The call pattern for this function looks like this: fn_arg_accept FLAGS LONGOPT DESCRIPTION DEFAULT. Example 1) fn_arg_accept 'r:' 'required-thing' 'Some thing I require'. Example 2) fn_arg_accept 'o?' 'optional-thing' 'Some optional thing'."
  "fn_arg_parse#Returns an associative array where the keys are arg names and the values are parsed arg values. Example 1) fn_arg_accept 'r:' 'required-thing' 'Some thing I require'; fn_arg_parse \"\$@\"; echo \"\$(fn_get_arg "required-thing")\""
  "fn_connect_db#A function that returns a connection string to a postgres database and throws if it can't establish a connection."
  "fn_sync_db_names#A function that syncs the database names to the config/.dbs file."
)

export repo_dir="$PWD"

fn_fail_on_used_port() {
  local port="$1"
  if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null; then
    log.warn "Port $port is already in use. skipping."
    exit 0
  fi
}
fn_print_line() {
  terminal_width=$(tput cols)
  line=$(printf "%${terminal_width}s" | tr " " "-")
  echo "$line"
}
fn_arg_info() {
  cmdarg_info "header" "$1: $2"
}
fn_arg_accept() {
  cmdarg "$@"
}
fn_arg_parse() {
  cmdarg_parse "$@"
}
fn_get_arg() {
  set +u
  echo "${cmdarg_cfg[$1]}"
  set -u
}
fn_connect_db() {
  connection_uri="postgres://$ENV_DB_USER:$ENV_POSTGRES_PASSWORD@database.server.$ENV_ROOT_DOMAIN:$ENV_DB_PORT/$1"
  status=$(psql "$connection_uri" -c "SELECT 1" || echo "NOT_READY")
  if [ "$status" '==' "NOT_READY" ]; then
    log.throw "Failed to connect to the postgres db: $1."
  fi
  echo "$connection_uri"
}
fn_sync_db_names() {
  connection_uri="postgres://$ENV_DB_USER:$ENV_POSTGRES_PASSWORD@database.server.$ENV_ROOT_DOMAIN:$ENV_DB_PORT/$ENV_DB_NAME"
  db_names=$(psql "$connection_uri" -q -A -t -c "SELECT datname FROM pg_database")
  rm -f "$repo_dir"/config/.dbs
  for db_name in $db_names; do
    if [ "$db_name" != "postgres" ] && [ "$db_name" != "template0" ] && [ "$db_name" != "template1" ]; then
      echo "$db_name" >>"$repo_dir"/config/.dbs
    fi
  done
}

# Check runtime_expectations and print documentation
for expected_runtime_variable in "${runtime_expectations[@]}"; do
  expected_runtime_variable_name=$(echo "$expected_runtime_variable" | cut -d "#" -f 1)
  if [ -z "$(eval echo "\$$expected_runtime_variable_name")" ]; then
    log.throw "$expected_runtime_variable_name is not set."
  fi
done
for runtime_variable in $(env | grep "^runtime_"); do
  runtime_variable_name=$(echo "$runtime_variable" | cut -d "=" -f 1)
  if [ -z "$(echo "${runtime_expectations[@]}" | grep "$runtime_variable_name")" ]; then
    if [[ $runtime_variable_name == "runtime_$dynamic_conn_string"* ]]; then
      continue
    fi
    log.throw "$runtime_variable_name is not expected."
  fi
done

mkdir -p "$repo_dir/.backups"
mkdir -p "$repo_dir/.tmp"
