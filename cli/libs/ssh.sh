#!/usr/bin/env bash

lib.ssh._validate() {
  local key_name="$1"
  local ip="$2"
  local project_dir="${HOME}/.solos/projects/${vPROJECT_NAME}"
  if [[ -z ${key_name} ]]; then
    log_error "key_name is required."
    exit 1
  fi
  if [[ -z ${ip} ]]; then
    log_error "ip is required."
    exit 1
  fi
  local key_path="${project_dir}/.ssh/${key_name}.priv"
  if [[ ! -f "${key_path}" ]]; then
    log_error "key file not found: ${key_path}"
    exit 1
  fi
  echo "${key_path}"
}

lib.ssh.cmd() {
  local key_name="$1"
  local ip="$2"
  local cmd="$3"
  local key_path="$(lib.ssh._validate "${key_name}" "${ip}")"
  ssh \
    -i "${key_path}" \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -o UserKnownHostsFile=/dev/null \
    "$@" root@"${ip}" \
    "${cmd}"
}

lib.ssh.rsync() {
  local key_name="$1"
  shift
  local ip="$1"
  shift
  local key_path="$(lib.ssh._validate "${key_name}" "${ip}")"
  rsync --checksum \
    -a \
    -e "ssh \
    -i ${key_path} \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -o UserKnownHostsFile=/dev/null" \
    "$@"
}

lib.ssh.pubkey() {
  local key_name="$1"
  local ssh_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/.ssh"
  if [[ -z ${key_name} ]]; then
    log_error "key_name is required."
    exit 1
  fi
  if [[ ! -d ${ssh_dir} ]]; then
    log_error "ssh directory not found: ${ssh_dir}"
    exit 1
  fi
  local pubkey_path="${ssh_dir}/${key_name}.pub"
  if [[ ! -f "${pubkey_path}" ]]; then
    log_error "key file not found: ${pubkey_path}"
    exit 1
  fi
  cat "${pubkey_path}"
}

lib.ssh.create() {
  local key_name="$1"
  local ssh_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/.ssh"
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
