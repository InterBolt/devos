#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-psql" "Safe way to invoke psql against a deployed DB."
fn_arg_accept 'db:' 'target-database' "The name of the database to connect to."
fn_arg_accept 'c:' 'command' "The command to run against the database."
fn_arg_accept 'f?' 'psql-flags' "The flags to pass to psql." ''
fn_arg_parse "$@"

target_database="$(fn_get_arg 'target-database')"
command="$(fn_get_arg 'command')"
psql_flags="$(fn_get_arg 'psql-flags')"

connection_uri="$(fn_connect_db "$target_database")"
# shellcheck disable=SC2086
psql "$connection_uri" $psql_flags -c "$command"
remote_dbs=$(psql "$connection_uri" -q -A -t -c "SELECT datname FROM pg_database")
rm -f "$repo_dir"/.secrets/db_connection_*
for remote_db in $remote_dbs; do
  if [ "$remote_db" != "postgres" ] && [ "$remote_db" != "template0" ] && [ "$remote_db" != "template1" ]; then
    echo "postgres://$runtime_postgres_user:$secret_postgres_password@$runtime_postgres_public_host:$runtime_postgres_port/$remote_db" >"$repo_dir"/.secrets/db_connection_"$remote_db"
  fi
done
