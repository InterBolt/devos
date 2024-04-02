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

# shellcheck disable=SC2155
export defaults_host="$(cat "$PWD/.host")"
export defaults_log_dir="$PWD/.logs"
#
# log.ready requires that the log dir already exist
#
mkdir -p "$defaults_log_dir"
log.ready "$defaults_host" "$defaults_log_dir" "${DEBUG_LEVEL:-0}"
