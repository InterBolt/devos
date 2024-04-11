#!/usr/bin/env bash
# shellcheck disable=SC2103,SC2164
set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd ..
fi
if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi
#
# The "fake" sourcing below ensures that any script we know we'll source within solos.sh
# can access shellcheck's IDE support and linting.
#
# shellcheck source=../solos.sh
. shared/empty.sh
# check if log.ready command exists
if ! command -v log.ready &>/dev/null; then
  # shellcheck source=log.sh
  . shared/log.sh
  #
  # Make sure the log.* functions are available if we are running in a script that
  # sources this file but for some reason isn't sourced from the main bin script.
  # NOTE: in reality, we only expect this to happen in the prototype phase of
  # writing a new script before depdendencies are established.
  #
  log.fallback_ready
fi
#
# Checking for the vFROM_BIN_SCRIPT variable protects us against accidentally running
# a script that should almost always only be source directly.
#
if [ "${vFROM_BIN_SCRIPT}" != "true" ]; then
  log.error "this script must be sourced from the main bin script"
  log.warn "tip: set vFROM_BIN_SCRIPT=true inside the script where you're sourcing solo_base.sh to suppress this error."
  exit 1
fi
