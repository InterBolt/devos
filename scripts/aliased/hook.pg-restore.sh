#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-pg-restore" "Restores the given backup file to the postgres database."
runtime_fn_arg_accept 'db:' 'target-database' "The name of the database to restore the backup to."
runtime_fn_arg_accept 'b:' 'backup-file-name' "The name of the backup file to restore."
runtime_fn_arg_accept 'u?' 'unsafe' "If provided, the script will not create a backup of the current db before restoring the backup." false
runtime_fn_arg_parse "$@"

target_database="$(runtime_fn_get_arg 'target-database')"
backup_file_name="$(runtime_fn_get_arg 'backup-file-name')"
unsafe="$(runtime_fn_get_arg 'unsafe')"

# IMPORTANT: don't ever refactor this to an arg validator because we prefer a more flexible and descriptive error message
# if the backup_filename does not end in *.$target_db.sql, then it is not a valid backup file
if [[ ! "$backup_file_name" =~ ^dump-.*\.$target_database.sql$ ]]; then
  log.throw "Please provide a valid backup file name. It must end with .$target_database.sql"
fi

connection_uri="$(runtime_fn_connect_db "$target_database")"
if [ -z "$backup_file_name" ] || [[ ! "$backup_file_name" =~ ^dump-.*\.sql$ ]]; then
  log.throw "Please provide a valid backup file name. It must start with dump- and end with .sql"
fi
"$runtime_repo_dir"/scripts/aliased/hook.pg-sync-down.sh
backup_file="$runtime_repo_dir/.backups/$backup_file_name"
if [ ! -f "$backup_file" ]; then
  log.throw "Backup file not found at $backup_file"
fi

# will skip making a backup before restoring the db
if [ "$unsafe" '==' "false" ]; then
  tmp_backup="$runtime_repo_dir/.tmp/dump-$(date +%Y-%m-%d-%H-%M-%S).sql"
  log.info "Dumping current db to $tmp_backup for safety"
  pg_dump "$connection_uri" >"$tmp_backup"

  log.info "Storing temp backup to vultr S3 bucket"
  "$runtime_repo_dir"/scripts/aliased/hook.pg-sync-up.sh
fi

log.info "Restoring $backup_file"
psql <"$backup_file" "$connection_uri" -q
log.info "If something went wrong you can restore the db with: h-pg-restore $tmp_backup"
