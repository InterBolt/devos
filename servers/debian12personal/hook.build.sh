#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-build" "Builds a repo using the specified strategy."
fn_arg_accept 'r:' 'repo-dir' 'The repo to deploy'
fn_arg_accept 's?' 'strategy' 'The deployment strategy' 'node/pnpm'
fn_arg_parse "$@"
repo_dir="$(fn_get_arg 'repo-dir')"
strategy="$(fn_get_arg 'strategy')"

if [[ ! "$strategy" == "node/pnpm" ]]; then
  log.throw "--strategy must be 'node/pnpm'"
fi
if [[ ! $repo_dir == $runtime_github_dir* ]]; then
  log.throw "--repo-dir must be a subdirectory of $runtime_github_dir"
fi

cd "$repo_dir"
pnpm run build
