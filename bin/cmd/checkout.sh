#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
. shared/empty.sh
# shellcheck source=../lib/ssh.sh
. shared/empty.sh
# shellcheck source=../lib/status.sh
. shared/empty.sh
# shellcheck source=../lib/store.sh
. shared/empty.sh
# shellcheck source=../lib/utils.sh
. shared/empty.sh
# shellcheck source=../lib/vultr.sh
. shared/empty.sh

cmd.checkout() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log.error "Unexpected error: please supply --project."
    exit 1
  fi
  log.info "Checking out ${vPROJECT_NAME}"
  sleep .5
  if [[ ! -d ${vSTATIC_SOLOS_PROJECTS_DIR} ]]; then
    mkdir -p "${vSTATIC_SOLOS_PROJECTS_DIR}"
  fi
  # If the project dir exists, let's assume it was setup ok.
  # We'll use a tmp dir to set it up so that any failures that occur
  # before we're done won't result in a partial project dir.
  if [[ ! -d ${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME} ]]; then
    local tmp_project_dir="$(mktemp -d)"
    if [[ ! -d ${tmp_project_dir} ]]; then
      log.error "Unexpected error: no tmp dir was created."
      exit 1
    fi
    local tmp_ssh_dir="${tmp_project_dir}/.ssh"
    mkdir -p "${tmp_ssh_dir}"
    lib.ssh.project_build_keypair "${tmp_ssh_dir}"
    lib.ssh.project_give_keyfiles_permissions "${tmp_ssh_dir}"
    cp -a "${tmp_project_dir}" "${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"
    rm -rf "${tmp_project_dir}"
  fi
  # We should be able to re-run the checkout command and pick up where we left
  # off if we didn't supply all the variables the first time.
  solos.collect_supplied_variables
  lib.store.global.set "project_name" "${vPROJECT_NAME}"
}
