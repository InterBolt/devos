#!/usr/bin/env bash

cmd.checkout() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "No project name was supplied."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects ]]; then
    mkdir -p "${HOME}/.solos/projects"
    log_info "No projects found. Creating ~/.solos/projects directory."
  fi
  # If the project dir exists, let's assume it was setup ok.
  # We'll use a tmp dir to build up the files so that unexpected errors
  # won't result in a partial project dir.
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    local project_id="$(lib.utils.generate_project_id)"
    local tmp_project_ssh_dir="$(mktemp -d)"
    if [[ ! -d ${tmp_project_ssh_dir} ]]; then
      log_error "Unexpected error: no tmp dir was created."
      exit 1
    fi
    lib.ssh.project_build_keypair "${tmp_project_ssh_dir}" || exit 1
    log_info "${vPROJECT_NAME} - Created keypair for project"
    lib.ssh.project_give_keyfiles_permissions "${tmp_project_ssh_dir}" || exit 1
    log_info "${vPROJECT_NAME} - Set permissions on keypair for project"
    mkdir -p "${HOME}/.solos/projects/${vPROJECT_NAME}"
    cp -a "${tmp_project_ssh_dir}" "${HOME}/.solos/projects/${vPROJECT_NAME}/.ssh"
    echo "${project_id}" >"${HOME}/.solos/projects/${vPROJECT_NAME}/id"
    log_info "${vPROJECT_NAME} - Established project directory"
  fi
  # We should be able to re-run the checkout command and pick up where we left
  # off if we didn't supply all the variables the first time.
  solos.prompts
  lib.store.global.set "checked_out_project" "${vPROJECT_NAME}"
  local vscode_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/.vscode"
  mkdir -p "${vscode_dir}"
  local tmp_dir="$(mktemp -d)"
  cp "${HOME}/.solos/src/launchfiles/solos.code-workspace" "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"
  if lib.utils.template_variables "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"; then
    cp -f "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace" "${vscode_dir}/solos-${vPROJECT_NAME}.code-workspace"
    log_info "${vPROJECT_NAME} - Successfully templated the Visual Studio Code workspace file."
  else
    log_error "${vPROJECT_NAME} - Failed to build the code workspace file."
    exit 1
  fi
  log_info "${vPROJECT_NAME} - Checkout out."
}
