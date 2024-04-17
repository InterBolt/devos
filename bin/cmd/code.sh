#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.code() {
  solos.require_completed_launch_status
  solos.checkout_project_dir
  solos.store_ssh_derived_ip

  if ! command -v "code" &>/dev/null; then
    log.error "vscode is not installed to your path. cannot continue."
  fi

  log.warn "would open vscode"
}
