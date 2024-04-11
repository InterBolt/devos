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

if [ "${vFROM_BIN_SCRIPT}" != "true" ]; then
  log.error "must run from the main bin script context"
  exit 1
fi
