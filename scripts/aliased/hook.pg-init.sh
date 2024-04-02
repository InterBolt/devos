#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-pg-init" "Downloads backups and ensures that we saved the correct db names to the filesystem."
runtime_fn_arg_parse "$@"

backups_dir="$runtime_repo_dir"/.backups
mkdir -p "$backups_dir"
"$runtime_repo_dir"/scripts/aliased/hook.pg-sync-down.sh
runtime_fn_sync_db_names
log.info "Postgres database setup. Use \`h-pg-restore --help\` for more info about restoring a backup file."
