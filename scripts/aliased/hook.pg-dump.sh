#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

if [ ! -f "scripts/aliased/hook.pg-sync-up.sh" ]; then
  log.throw "scripts/aliased/hook.pg-sync-up.sh doesn't exist"
fi

runtime_fn_arg_info "h-pg-dump" "Creates and (by default) uploads a dump of a postgres db to a vultr S3 bucket."
runtime_fn_arg_accept 'db:' 'database' 'The output folder for a build that also contains any app specific env files.'
runtime_fn_arg_accept 'l?' 'local-only' 'If set, the dump will not be uploaded to the vultr s3 bucket.' false
runtime_fn_arg_parse "$@"

database="$(runtime_fn_get_arg 'database')"
local_Only="$(runtime_fn_get_arg 'local-only')"

connection_uri="$(runtime_fn_connect_db "$database")"
pg_dump "$connection_uri" >"$runtime_repo_dir"/.backups/dump-"$(date +%Y-%m-%d-%H-%M-%S)"."$database".sql
[ "$local_Only" '==' 'true' ] && exit 0
"$runtime_repo_dir"/scripts/aliased/hook.pg-sync-up.sh
