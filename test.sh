#!/usr/bin/env bash

vPROJECT_NAME="interbolt"

lib.ssh.create() {
  local key_name="$1"
  local project_dir="${HOME}/.solos/projects/${vPROJECT_NAME}"
  local ssh_dir="${project_dir}/.ssh"
  mkdir -p "${ssh_dir}"
  local privkey_path="${ssh_dir}/${key_name}.priv"
  local pubkey_path="${ssh_dir}/${key_name}.pub"
  if [[ -z ${key_name} ]]; then
    log_error "key_name is required."
    exit 1
  fi
  if [[ -f ${privkey_path} ]]; then
    log_error "key file already exists: ${privkey_path}"
    exit 1
  fi
  if [[ -f ${pubkey_path} ]]; then
    log_error "key file already exists: ${pubkey_path}"
    exit 1
  fi
  local entry_dir="${PWD}"
  cd "${ssh_dir}" || exit 1
  if ! ssh-keygen -t rsa -q -f "${privkey_path}" -N "" >/dev/null; then
    log_error "Could not create SSH keypair."
  else
    mv "${privkey_path}.pub" "${pubkey_path}"
    chmod 644 "${pubkey_path}"
    chmod 600 "${privkey_path}"
  fi
  cd "${entry_dir}" || exit 1
}

lib.ssh.create "$1"
