#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

PREFIX="app_"

validate_app_db_name() {
  if [[ "$1" =~ ^"$PREFIX".* ]]; then
    return 0
  fi
  return 1
}
fn_arg_info "h-pg-register-db" "Create a new DB for an app."
fn_arg_accept 'a:' 'app-db' "The name of the new database to create. It must be prefixed with $PREFIX." '' validate_app_db_name
fn_arg_parse "$@"
app_db="$(fn_get_arg 'app-db')"

connection_uri="$(fn_connect_db "$runtime_postgres_db")"
psql "$connection_uri" -c "CREATE DATABASE $app_db"
fn_sync_db_names
