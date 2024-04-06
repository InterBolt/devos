#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-pg-init" "Downloads backups and ensures that we saved the correct db names to the filesystem."
fn_arg_parse "$@"

"$repo_dir"/cmds/hook.pg-sync-down.sh
fn_sync_db_names
log.info "Postgres database setup. Use \`h-pg-restore --help\` for more info about restoring a backup file."
