#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-rsync-secrets" "Syncs secrets between the local and remote machine."
fn_arg_parse "$@"

rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /root/.ssh/$runtime_ssh_key_name" "$repo_dir"/.secrets/. root@"$secret_remote_ip":"$repo_dir"/.secrets/
