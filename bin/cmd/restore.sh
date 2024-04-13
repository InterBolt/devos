#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.restore() {
  solos.require_completed_launch_status
  cmd.checkout

  if [[ "$vSTATIC_HOST" = "local" ]]; then
    lib.validate.docker_host_running
  fi
  log.warn "TODO: implementation needed"
}
