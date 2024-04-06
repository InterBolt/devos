#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit
cd "$(git rev-parse --show-toplevel)" || exit

(shopt -p inherit_errexit &>/dev/null) && shopt -s inherit_errexit

# shellcheck source=../../installer/bin/shared.log.sh
. installer/bin/shared.log.sh
# shellcheck source=defaults.cmdargs.sh
. defaults.cmdargs.sh
# shellcheck source=defaults.lobash.bash
. scripts/lib/defaults.lobash.bash
# shellcheck source=../../.env.sh
. "$PWD/.env.sh"

log.ready "host:$ENV_HOST" "${DEBUG_LEVEL:-0}"
