#!/usr/bin/env bash

# shellcheck source=proxy-lib.sh
. "${HOME}"/.solos/src/bin/proxy-lib.sh || exit 1

run_cmd_in_docker /root/.solos/src/bin/solos.sh --restricted-developer "$@"
