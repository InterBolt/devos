#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "i-node" "Installs NodeJS and related tooling."
runtime_fn_arg_parse "$@"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
# shellcheck source=/root/.bashrc
source /root/.bashrc
nvm install $runtime_node_version
nvm use $runtime_node_version
source /root/.bashrc
npm install --global pnpm @vscode/vsce
source /root/.bashrc
