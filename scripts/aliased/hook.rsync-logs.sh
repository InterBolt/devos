#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
source ../../.env.sh
# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-rsync-logs" "Download logs from the remote machine to the local machine."
runtime_fn_arg_parse "$@"

rsync -avz -e "ssh -o StrictHostKeyChecking=no -i /root/.ssh/$runtime_ssh_key_name" root@"$secret_remote_ip":"$runtime_repo_dir"/.logs/. "$runtime_repo_dir"/.logs/
