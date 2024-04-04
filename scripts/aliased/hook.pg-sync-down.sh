#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
source ../../.env.sh
# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-pg-sync-down" "Syncs backups on vultr to the local machine."
runtime_fn_arg_parse "$@"

export AWS_ACCESS_KEY_ID=$secret_vultr_s3_access
export AWS_SECRET_ACCESS_KEY=$secret_vultr_s3_secret

aws --endpoint-url="https://$secret_vultr_s3_host" s3 sync "s3://postgres/backups" .backups --exclude ".*" --acl private
aws --endpoint-url="https://$secret_vultr_s3_host" s3 sync "s3://postgres/tmp" .tmp --exclude ".*" --acl private

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
