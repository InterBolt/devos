#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit
cd "$(git rev-parse --show-toplevel)" || exit

(shopt -p inherit_errexit &>/dev/null) && shopt -s inherit_errexit

# shellcheck source=../../installer/bin/shared.log.sh
source installer/bin/shared.log.sh
# shellcheck source=defaults.cmdargs.sh
source defaults.cmdargs.sh
# shellcheck source=defaults.lobash.bash
source scripts/lib/defaults.lobash.bash
# shellcheck source=../../.env.sh
source "$PWD/.env.sh"

log.ready "debian:$ENV_HOST" "${DEBUG_LEVEL:-0}"
