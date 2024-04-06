#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-rsync-logs" "Download logs from the remote machine to the local machine."
fn_arg_parse "$@"

rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /root/.ssh/$runtime_ssh_key_name" root@"$secret_remote_ip":"$repo_dir"/.logs/. "$repo_dir"/.logs/
