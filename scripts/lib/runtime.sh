#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

if [ "$(lsb_release -is)" != "Debian" ] || [ "$(lsb_release -rs)" != "12" ]; then
  echo "This script is only supported on Debian 12"
  exit 1
fi

# shellcheck source=defaults.sh
source defaults.sh

dynamic_conn_string="db_connection"
# The list of variables that are expected to be set at runtime.
# The format is "name#description".
runtime_expectations=(
  # values
  "runtime_expectations#The list of variables that are expected to be set at runtime."
  "runtime_host#The host that a script is running on. It is initialized when dev-os is installed. It is set to 'remote' when the script is running on the remote server and 'local' when the script is running on the local machine."
  "runtime_repo_dir#The DevOS repo directory."
  "runtime_config_dir#The directory configuration files are stored."
  "runtime_secrets_dir#The directory where secrets are stored."
  "runtime_ssh_key_name#The name of the SSH key used between environments."
  "runtime_log_dir#The directory where logs are stored."
  "runtime_apps_dir#The directory where apps live."
  "runtime_github_dir#The directory where source code lives."
  "runtime_caprover_root_domain#The root domain of the caprover server."
  "runtime_caprover_name#The name of the caprover server."
  "runtime_caprover_email#The email of the caprover server."
  "runtime_node_version#The node version to use."
  "runtime_artifacts_dir#The directory where artifacts are stored."
  "runtime_caprover_api_calls_dir#The directory where caprover api calls are stored."
  "runtime_postgres_subdomain#The subdomain of the postgres server."
  "runtime_postgres_db#The name of the postgres database."
  "runtime_postgres_user#The name of the postgres user."
  "runtime_postgres_port#The port of the postgres server."
  "runtime_postgres_public_host#The public host of the postgres server."

  # secrets
  "secret_remote_ip#The remote ip address of the production server."
  "secret_vultr_s3_host#The vultr s3 host."
  "secret_vultr_s3_secret#The vultr s3 secret."
  "secret_vultr_s3_access#The vultr s3 access key"
  "secret_vultr_s3_store#The vultr s3 store label."
  "secret_name#The name of this DevOS installation."
  "secret_workspace_dir#The workspace directory."
  "secret_github_username#The github username."
  "secret_github_email#The github email"
  "secret_gh_token#The github api token."
  "secret_openai#The openai api key."
  "secret_vultr_api_key#The vultr api key."
  "secret_cloudflare_api_token#The cloudflare api token."
  "secret_caprover_password#The caprover password."
  "secret_postgres_password#The postgres password."

  # functions
  "runtime_fn_fail_on_used_port#A function that fails if a port is already in use."
  "runtime_fn_print_line#A function that prints a line the width of the user's terminal. Useful for displaying some forms of data."
  "runtime_fn_arg_info#A function whose first argument is the aliased name of a script and second argument is the description of the script. Automatically supplied the information to the output when the user includes a --help flag."
  "runtime_fn_arg_accept#The call pattern for this function looks like this: runtime_fn_arg_accept FLAGS LONGOPT DESCRIPTION DEFAULT. Example 1) runtime_fn_arg_accept 'r:' 'required-thing' 'Some thing I require'. Example 2) runtime_fn_arg_accept 'o?' 'optional-thing' 'Some optional thing'."
  "runtime_fn_arg_parse#Returns an associative array where the keys are arg names and the values are parsed arg values. Example 1) runtime_fn_arg_accept 'r:' 'required-thing' 'Some thing I require'; runtime_fn_arg_parse \"\$@\"; echo \"\$(runtime_fn_get_arg "required-thing")\""
  "runtime_fn_connect_db#A function that returns a connection string to a postgres database and throws if it can't establish a connection."
  "runtime_fn_sync_db_names#A function that syncs the database names to the config/.dbs file."
)

# Set the runtime variables.
# shellcheck disable=SC2155
export runtime_repo_dir="$PWD"
export runtime_host="$defaults_host"
export runtime_log_dir="$defaults_log_dir"
export runtime_config_dir="$runtime_repo_dir/config"
export runtime_secrets_dir=$runtime_repo_dir/.secrets
export runtime_ssh_key_name=devos
export runtime_caprover_root_domain=server.interbolt.org
export runtime_caprover_name="interbolt"
export runtime_caprover_email="cc13.engineering@gmail.com"
export runtime_node_version=20.11.1
export runtime_caprover_api_calls_dir=$runtime_repo_dir/caprover-api-calls
export runtime_postgres_subdomain=database
export runtime_postgres_db=manager
export runtime_postgres_user=devos
export runtime_postgres_port=5432
export runtime_postgres_public_host=database.server.interbolt.org

for secret_name in $(ls "$runtime_secrets_dir" | grep -v "^\."); do
  export secret_"$secret_name"="$(cat "$runtime_secrets_dir/$secret_name")"
done
export secret_workspace_dir="$secret_workspace_dir"
export secret_remote_ip="$secret_remote_ip"
export secret_vultr_s3_host="$secret_vultr_s3_host"
export secret_vultr_s3_secret="$secret_vultr_s3_secret"
export secret_vultr_s3_access="$secret_vultr_s3_access"
export secret_vultr_s3_store="$secret_vultr_s3_store"
export secret_name="$secret_name"
export secret_github_username="$secret_github_username"
export secret_github_email="$secret_github_email"
export secret_gh_token="$secret_gh_token"
export secret_openai="$secret_openai"
export secret_vultr_api_key="$secret_vultr_api_key"
export secret_cloudflare_api_token="$secret_cloudflare_api_token"
export secret_caprover_password="$secret_caprover_password"
export secret_postgres_password="$secret_postgres_password"

export runtime_apps_dir=$secret_workspace_dir/apps
export runtime_github_dir=$secret_workspace_dir/github
export runtime_artifacts_dir=$secret_workspace_dir/.artifacts

runtime_fn_fail_on_used_port() {
  local port="$1"
  if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null; then
    log.warn "Port $port is already in use. skipping."
    exit 0
  fi
}
runtime_fn_print_line() {
  terminal_width=$(tput cols)
  line=$(printf "%${terminal_width}s" | tr " " "-")
  echo "$line"
}
runtime_fn_arg_info() {
  cmdarg_info "header" "$1: $2"
}
runtime_fn_arg_accept() {
  cmdarg "$@"
}
runtime_fn_arg_parse() {
  cmdarg_parse "$@"
}
runtime_fn_get_arg() {
  set +u
  echo "${cmdarg_cfg[$1]}"
  set -u
}
runtime_fn_connect_db() {
  connection_uri="postgres://$runtime_postgres_user:$secret_postgres_password@$runtime_postgres_public_host:$runtime_postgres_port/$1"
  status=$(psql "$connection_uri" -c "SELECT 1" || echo "NOT_READY")
  if [ "$status" '==' "NOT_READY" ]; then
    log.throw "Failed to connect to the postgres db: $1."
  fi
  echo "$connection_uri"
}
runtime_fn_sync_db_names() {
  connection_uri="postgres://$runtime_postgres_user:$secret_postgres_password@$runtime_postgres_public_host:$runtime_postgres_port/$runtime_postgres_db"
  db_names=$(psql "$connection_uri" -q -A -t -c "SELECT datname FROM pg_database")
  rm -f "$runtime_repo_dir"/config/.dbs
  for db_name in $db_names; do
    if [ "$db_name" != "postgres" ] && [ "$db_name" != "template0" ] && [ "$db_name" != "template1" ]; then
      echo "$db_name" >>"$runtime_repo_dir"/config/.dbs
    fi
  done
}
export runtime_fn_fail_on_used_port=runtime_fn_fail_on_used_port
export runtime_fn_print_line=runtime_fn_print_line
export runtime_fn_arg_info=runtime_fn_arg_info
export runtime_fn_arg_accept=runtime_fn_arg_accept
export runtime_fn_arg_parse=runtime_fn_arg_parse
export runtime_fn_get_arg=runtime_fn_get_arg
export runtime_fn_connect_db=runtime_fn_connect_db
export runtime_fn_sync_db_names=runtime_fn_sync_db_names

mkdir -p $runtime_apps_dir
mkdir -p $runtime_github_dir
mkdir -p $runtime_artifacts_dir

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
