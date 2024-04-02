#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-rsync-secrets" "Syncs secrets between the local and remote machine."
runtime_fn_arg_parse "$@"

rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /root/.ssh/$runtime_ssh_key_name" "$runtime_repo_dir"/.secrets/. root@"$secret_remote_ip":"$runtime_repo_dir"/.secrets/
