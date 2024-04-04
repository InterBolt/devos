#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
source ../../.env.sh
# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-build" "Builds a repo using the specified strategy."
runtime_fn_arg_accept 'r:' 'repo-dir' 'The repo to deploy'
runtime_fn_arg_accept 's?' 'strategy' 'The deployment strategy' 'node/pnpm'
runtime_fn_arg_parse "$@"
repo_dir="$(runtime_fn_get_arg 'repo-dir')"
strategy="$(runtime_fn_get_arg 'strategy')"

if [[ ! "$strategy" == "node/pnpm" ]]; then
  log.throw "--strategy must be 'node/pnpm'"
fi
if [[ ! $repo_dir == $runtime_github_dir* ]]; then
  log.throw "--repo-dir must be a subdirectory of $runtime_github_dir"
fi

cd "$repo_dir"
pnpm run build
