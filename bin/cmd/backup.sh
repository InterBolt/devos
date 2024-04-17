#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

cmd.backup() {
  solos.require_completed_launch_status
  solos.checkout_project_dir
  solos.detect_remote_ip

  log.warn "TODO: implementation needed"
}
