#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.code() {
  solos.require_completed_launch_status
  cmd.checkout

  if ! command -v "code" &>/dev/null; then
    log.error "vscode is not installed to your path. cannot continue."
  fi
  if [ "${vSTATIC_HOST}" != "local" ]; then
    log.error "this command must be run from the local host. Exiting."
    exit 1
  fi
  lib.validate.docker_host_running

  log.warn "would open vscode"
}
