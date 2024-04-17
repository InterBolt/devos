#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.restore() {
  solos.require_completed_launch_status
  solos.checkout_project_dir
  solos.store_ssh_derived_ip

  log.warn "TODO: implementation needed"
}
