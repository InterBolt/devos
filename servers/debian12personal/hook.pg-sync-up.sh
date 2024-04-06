#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-pg-sync-up" "Uploads any unsynced backups from this local machine to vultr."
fn_arg_parse "$@"

export AWS_ACCESS_KEY_ID=$secret_vultr_s3_access
export AWS_SECRET_ACCESS_KEY=$secret_vultr_s3_secret

aws --endpoint-url="https://$secret_vultr_s3_host" s3 sync .backups "s3://postgres/backups" --exclude ".*" --acl private
aws --endpoint-url="https://$secret_vultr_s3_host" s3 sync .tmp "s3://postgres/tmp" --exclude ".*" --acl private

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
