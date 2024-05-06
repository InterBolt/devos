#!/usr/bin/env bash

# shellcheck source=lib.sh
. "${HOME}"/.solos/src/bin/posix.run.sh || exit 1

__base__fn__run /root/.solos/src/bin/solos.sh --restricted-developer "$@"
