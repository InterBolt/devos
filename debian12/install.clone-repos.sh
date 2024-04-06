#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "i-clone-repos" "Clones orginization's repos."
fn_arg_parse "$@"

cd $runtime_github_dir
gh repo list interbolt --limit 4000 | while read -r repo _; do
  name=$(basename "$repo")
  if [ "$name" = "solos" ]; then
    continue
  fi
  if [ ! -d "${name}" ]; then
    gh repo clone "$repo" "$name"
  fi
done
