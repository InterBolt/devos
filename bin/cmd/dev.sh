#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

cmd.code() {
  solos.require_completed_launch_status
  solos.checkout_project_dir
  solos.detect_remote_ip

  if ! command -v "code" &>/dev/null; then
    log.error "vscode is not installed to your path. cannot continue."
  fi

  log.warn "would open vscode"
}
