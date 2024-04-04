#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
source ../../.env.sh
# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

PREFIX="app_"

validate_app_db_name() {
  if [[ "$1" =~ ^"$PREFIX".* ]]; then
    return 0
  fi
  return 1
}
runtime_fn_arg_info "h-pg-register-db" "Create a new DB for an app."
runtime_fn_arg_accept 'a:' 'app-db' "The name of the new database to create. It must be prefixed with $PREFIX." '' validate_app_db_name
runtime_fn_arg_parse "$@"
app_db="$(runtime_fn_get_arg 'app-db')"

connection_uri="$(runtime_fn_connect_db "$runtime_postgres_db")"
psql "$connection_uri" -c "CREATE DATABASE $app_db"
runtime_fn_sync_db_names
