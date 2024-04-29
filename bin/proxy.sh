#!/usr/bin/env bash

ENTRY_DIR="${PWD}"
# shellcheck source=proxy-lib.sh
. .solos/src/bin/proxy-lib.sh || exit 1

run_solos_in_docker "${ENTRY_DIR}" --restricted-machine-home-path="${HOME}" "$@"
