#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
. shared/empty.sh

lib.ssh._validate() {
  if [[ -z ${!vDETECTED_REMOTE_IP+x} ]]; then
    log.error "vDETECTED_REMOTE_IP must be defined. Exiting."
    exit 1
  fi
}

lib.ssh._require_ip() {
  if [[ -z ${vDETECTED_REMOTE_IP} ]]; then
    log.error "vDETECTED_REMOTE_IP must be defined. Exiting."
    exit 1
  fi
}

lib.ssh.command() {
  lib.ssh._validate
  lib.ssh._require_ip
  local cmd="$1"
  shift
  ssh -i "$vOPT_PROJECT_DIR/.ssh/id_rsa" -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null "$@" root@"${vDETECTED_REMOTE_IP}" "${cmd}"
}

lib.ssh.rsync_up() {
  lib.ssh._validate
  lib.ssh._require_ip
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -i $vOPT_PROJECT_DIR/.ssh/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" "${source}" root@"${vDETECTED_REMOTE_IP}":"${target}"
}

lib.ssh.rsync_down() {
  lib.ssh._validate
  lib.ssh._require_ip
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -i $vOPT_PROJECT_DIR/.ssh/id_rsa -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" root@"${vDETECTED_REMOTE_IP}":"${target}" "${source}"
}

lib.ssh.cat_pubkey() {
  if [[ -f "$vOPT_PROJECT_DIR/.ssh/id_rsa.pub" ]]; then
    cat "$vOPT_PROJECT_DIR/.ssh/id_rsa.pub"
  else
    echo ""
  fi
}

lib.ssh.build_keypairs() {
  local self_publickey_path="$vOPT_PROJECT_DIR/.ssh/id_rsa.pub"
  local self_privkey_path="$vOPT_PROJECT_DIR/.ssh/id_rsa"
  local self_authorized_keys_path="$vOPT_PROJECT_DIR/.ssh/authorized_keys"
  local self_config_path="$vOPT_PROJECT_DIR/.ssh/ssh_config"
  local self_ssh_dir_path="$vOPT_PROJECT_DIR/.ssh"

  # Only create keypair. We create the config elsewhere.
  if [[ ! -d ${self_ssh_dir_path} ]]; then
    mkdir -p "${self_ssh_dir_path}"
    ssh-keygen -t rsa -q -f "${self_privkey_path}" -N "" >/dev/null
    cat "${self_publickey_path}" >"${self_authorized_keys_path}"
    log.info "Created ssh keypair."
  fi
  chmod 644 "${self_authorized_keys_path}"
  chmod 644 "${self_publickey_path}"
  chmod 644 "${self_config_path}"
  chmod 600 "${self_privkey_path}"
  log.info "Prepared the project's .ssh directory."
}

lib.ssh.build.config_file() {
  local ip="$1"
  if ! [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log.error "can't build the ssh config file with the invalid IP: ${ip}"
    exit 1
  fi
  local privatekey_file="$vOPT_PROJECT_DIR/.ssh/id_rsa"
  local config_file="$vOPT_PROJECT_DIR/.ssh/ssh_config"
  {
    echo "Host 127.0.0.1"
    echo "  HostName solos-docker"
    echo "  User root"
    echo "  IdentityFile ${privatekey_file}"
    echo "  Port 2222"
    echo ""
    echo ""
    echo "Host ${ip}"
    echo "  HostName solos-remote"
    echo "  User root"
    echo "  IdentityFile ${privatekey_file}"
  } >"${config_file}"
  log.info "created: ${config_file}."
}

lib.ssh.extract_ip() {
  #
  # We always use the ssh config file as our source of truth for the IP address.
  #
  local match_string="HostName solos-remote"
  local ip=$(grep -B 1 "${match_string}" "${vOPT_PROJECT_DIR}/.ssh/ssh_config" | grep -v "${match_string}" | tail -n 1 | cut -d' ' -f 2)
  if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${ip}"
  else
    echo ""
  fi
}
