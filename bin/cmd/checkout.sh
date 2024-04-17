#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.checkout() {
  solos.checkout_project_dir
  solos.store_ssh_derived_ip
}
