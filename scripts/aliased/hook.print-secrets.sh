#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
source ../../.env.sh
# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-print-secrets" "Prints the contents of the .secrets directory."
runtime_fn_arg_parse "$@"

for secret in .secrets/*; do
  if [ ! -f "$secret" ]; then
    break
  fi
  echo -e "secret_$(basename "$secret")\t$(cat "$secret")"
done
