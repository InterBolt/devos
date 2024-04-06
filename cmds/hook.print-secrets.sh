#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-print-secrets" "Prints the contents of the .secrets directory."
fn_arg_parse "$@"

for secret in .secrets/*; do
  if [ ! -f "$secret" ]; then
    break
  fi
  echo -e "secret_$(basename "$secret")\t$(cat "$secret")"
done
