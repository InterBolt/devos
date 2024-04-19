#!/usr/bin/env bash

ENTRY_DIR="${PWD}"
# shellcheck source=proxy-lib.sh
. "${HOME}"/.solos/src/bin/proxy-lib.sh || exit 1

run_solos_in_docker --restricted-volume-ctx="$(echo_ctx "${ENTRY_DIR}")" "$@"
