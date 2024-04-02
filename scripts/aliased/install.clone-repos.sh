#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "i-clone-repos" "Clones orginization's repos."
runtime_fn_arg_parse "$@"

cd $runtime_github_dir
gh repo list interbolt --limit 4000 | while read -r repo _; do
  name=$(basename "$repo")
  if [ "$name" = "devos" ]; then
    continue
  fi
  if [ ! -d "${name}" ]; then
    gh repo clone "$repo" "$name"
  fi
done
