#!/usr/bin/env bash

. "${HOME}"/.solos/src/bin/docker.sh || exit 1

__docker__fn__run /root/.solos/src/bin/solos.sh "$@"
