#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../bin.sh
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
  if [[ ! -d ${vSTATIC_SOLOS_PROJECTS_DIR} ]]; then
    mkdir -p "${vSTATIC_SOLOS_PROJECTS_DIR}"
    log.info "No projects found. Creating ~/.solos/projects directory."
  fi
  # If the project dir exists, let's assume it was setup ok.
  # We'll use a tmp dir to build up the files so that unexpected errors
  # won't result in a partial project dir.
  if [[ ! -d ${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME} ]]; then
    local project_id="$(lib.utils.generate_project_id)"
    local tmp_project_ssh_dir="$(mktemp -d)"
    if [[ ! -d ${tmp_project_ssh_dir} ]]; then
      log.error "Unexpected error: no tmp dir was created."
      exit 1
    fi
    lib.ssh.project_build_keypair "${tmp_project_ssh_dir}" || exit 1
    log.info "${vPROJECT_NAME} - Created keypair for project"
    lib.ssh.project_give_keyfiles_permissions "${tmp_project_ssh_dir}" || exit 1
    log.info "${vPROJECT_NAME} - Set permissions on keypair for project"
    mkdir -p "${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"
    cp -a "${tmp_project_ssh_dir}" "${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/.ssh"
    echo "${project_id}" >"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/id"
    log.info "${vPROJECT_NAME} - Established project directory"
  fi
  # We should be able to re-run the checkout command and pick up where we left
  # off if we didn't supply all the variables the first time.
  solos.collect_supplied_variables
  lib.store.global.set "project_name" "${vPROJECT_NAME}"

  local vscode_dir="${HOME}/.solos/.vscode"
  mkdir -p "${vscode_dir}"
  local tmp_dir="$(mktemp -d)"
  cp launch/solos.code-workspace "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"
  if lib.utils.template_variables "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"; then
    cp -f "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace" "${vscode_dir}/solos-${vPROJECT_NAME}.code-workspace"
    log.info "${vPROJECT_NAME} - Successfully templated the Visual Studio Code workspace file."
  else
    log.error "${vPROJECT_NAME} - Failed to build the code workspace file."
    exit 1
  fi
  log.info "${vPROJECT_NAME} - Checkout out."
}
