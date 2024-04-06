#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-pg-expire-backups" "Retires any backups older than 30 days from the vultr s3 bucket."
fn_arg_parse "$@"

export AWS_ACCESS_KEY_ID="$secret_vultr_s3_access"
export AWS_SECRET_ACCESS_KEY="$secret_vultr_s3_secret"

# I need to loop through the remote bucket folder /backups and delete any files older than 30 days.
aws --endpoint-url="https://$secret_vultr_s3_host" s3 ls "s3://postgres/backups" --recursive | while read -r line; do
  filename=$(echo "$line" | awk '{print $4}')
  if [[ $filename == "backups/old/"* ]]; then
    continue
  fi
  filedate=$(echo "$filename" | awk -F'-' '{print $2"-"$3"-"$4}')
  filedateepoch=$(date -d "$filedate" +%s)
  currentdateepoch=$(date +%s)
  filename=$(echo "$filename" | awk -F'/' '{print $2}')
  if [ $((currentdateepoch - filedateepoch)) -gt 2592000 ]; then
    aws --endpoint-url="https://$secret_vultr_s3_host" s3 mv "s3://postgres/backups/$filename" "s3://postgres/backups/old/$filename" >/dev/null
    log.info "Retired backup: $filename"
  fi
done

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
