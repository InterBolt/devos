#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "i-node" "Installs NodeJS and related tooling."
fn_arg_parse "$@"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
# shellcheck source=/root/.bashrc
. /root/.bashrc
nvm install $runtime_node_version
nvm use $runtime_node_version
. /root/.bashrc
npm install --global pnpm @vscode/vsce
. /root/.bashrc
