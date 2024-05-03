#!/usr/bin/env bash

# shellcheck source=lib.sh
. "${HOME}"/.solos/src/bin/lib.sh || exit 1

containerized_run /root/.solos/src/bin/bin.sh "$@"
