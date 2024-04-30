#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
. shared/empty.sh

lib.ssh.project_command() {
  local project_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"}"
  local cmd="$1"
  shift
  ssh -i "${project_dir}/.ssh/id_rsa" -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null "$@" root@"${vPROJECT_IP}" "${cmd}"
}

lib.ssh.project_rsync_up() {
  local project_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"}"
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -i ${project_dir}/.ssh/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" "${source}" root@"${vPROJECT_IP}":"${target}"
}

lib.ssh.project_rsync_down() {
  local project_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"}"
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -i ${project_dir}/.ssh/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" root@"${vPROJECT_IP}":"${target}" "${source}"
}

lib.ssh.project_cat_pubkey() {
  local project_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"}"
  if [[ -f "${project_dir}/.ssh/id_rsa.pub" ]]; then
    cat "${project_dir}/.ssh/id_rsa.pub"
  else
    echo ""
  fi
}

lib.ssh.project_build_keypair() {
  local ssh_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/.ssh"}"

  local publickey_path="${ssh_dir}/id_rsa.pub"
  local privkey_path="${ssh_dir}/id_rsa"
  local authorized_keys_path="${ssh_dir}/authorized_keys"

  if [[ ! -f ${privkey_path} ]]; then
    local entry_dir="$(pwd)"
    mkdir -p "${ssh_dir}"
    cd "${ssh_dir}" || exit 1
    if ! ssh-keygen -t rsa -q -f "${privkey_path}" -N "" >/dev/null; then
      log.error "Could not create SSH keypair."
      exit 1
    fi
    cd "${entry_dir}" || exit 1
    cat "${publickey_path}" >"${authorized_keys_path}"
  else
    local missing=false
    for file in "${publickey_path}" "${privkey_path}" "${authorized_keys_path}"; do
      if [[ ! -f ${file} ]]; then
        log.error "Missing SSH keyfile: ${file}"
        missing=true
      fi
    done
    if [[ ${missing} = true ]]; then
      log.error "Incomplete SSH keyfiles."
      exit 1
    fi
  fi
}

lib.ssh.project_give_keyfiles_permissions() {
  local ssh_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/.ssh"}"

  local publickey_path="${ssh_dir}/id_rsa.pub"
  local privkey_path="${ssh_dir}/id_rsa"
  local authorized_keys_path="${ssh_dir}/authorized_keys"
  local config_path="${ssh_dir}/config"

  # This is the only file that we should ever create in an empty state.
  if [[ ! -f ${config_path} ]]; then
    touch "${config_path}"
  fi

  chmod 644 "${authorized_keys_path}"
  chmod 644 "${publickey_path}"
  chmod 644 "${config_path}"
  chmod 600 "${privkey_path}"
}

lib.ssh.project_build_config() {
  local project_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"}"
  local ip="$1"
  if ! [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log.error "can't build the ssh config file with the invalid IP: ${ip}"
    exit 1
  fi
  local privatekey_file="${project_dir}/.ssh/id_rsa"
  local config_file="${project_dir}/.ssh/config"
  {
    echo "Host ${ip}"
    echo "  HostName solos"
    echo "  User root"
    echo "  IdentityFile ${privatekey_file}"
  } >"${config_file}"
  log.info "created: ${config_file}."
}

lib.ssh.project_extract_project_ip() {
  local project_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"}"
  local config_file="${project_dir}/.ssh/config"
  if [[ ! -f ${config_file} ]]; then
    echo ""
    return
  fi
  local match_string="HostName solos"
  local ip=$(grep -B 1 "${match_string}" "${config_file}" | grep -v "${match_string}" | tail -n 1 | cut -d' ' -f 2)
  if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${ip}"
  else
    echo ""
  fi
}

lib.ssh.project_load_docker_image() {
  local project_dir="${1:-"${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"}"
  ssh -i "${project_dir}/.ssh/id_rsa" -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -C root@"${vPROJECT_IP}" 'docker load'
}
