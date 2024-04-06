#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

if [ ! -f "cmds/hook.pg-sync-up.sh" ]; then
  log.throw "cmds/hook.pg-sync-up.sh doesn't exist"
fi

fn_arg_info "h-pg-dump" "Creates and (by default) uploads a dump of a postgres db to a vultr S3 bucket."
fn_arg_accept 'db:' 'database' 'The output folder for a build that also contains any app specific env files.'
fn_arg_accept 'l?' 'local-only' 'If set, the dump will not be uploaded to the vultr s3 bucket.' false
fn_arg_parse "$@"

database="$(fn_get_arg 'database')"
local_Only="$(fn_get_arg 'local-only')"

connection_uri="$(fn_connect_db "$database")"
pg_dump "$connection_uri" >"$repo_dir"/.backups/dump-"$(date +%Y-%m-%d-%H-%M-%S)"."$database".sql
[ "$local_Only" '==' 'true' ] && exit 0
"$repo_dir"/cmds/hook.pg-sync-up.sh
