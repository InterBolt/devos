#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

lib.ssh._validate() {
  if [ -z "${!vENV_IP+x}" ]; then
    log.error "vENV_IP must be defined. Exiting."
    exit 1
  fi
}
lib.ssh._require_ip() {
  if [ -z "${vENV_IP}" ]; then
    log.error "vENV_IP must be defined. Exiting."
    exit 1
  fi
}
lib.ssh.command.docker() {
  lib.ssh._validate
  if [ "$vSTATIC_HOST" != "local" ]; then
    log.error "$0 must be run locally to interact with docker over SSH. Exiting."
    exit 1
  fi
  local cmd="$1"
  shift
  ssh -p 2222 -i "$(lib.ssh.path_privkey.self)" -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null "$@" root@127.0.0.1 "$cmd"
}
lib.ssh.command.remote() {
  lib.ssh._validate
  lib.ssh._require_ip
  if [ "$vSTATIC_HOST" == "remote" ]; then
    log.error "$0 must be run locally or in the dev docker container. Exiting."
    exit 1
  fi
  local cmd="$1"
  shift
  ssh -i "$(lib.ssh.path_privkey.self)" -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null "$@" root@"$vENV_IP" "$cmd"
}
lib.ssh.rsync_up.docker() {
  lib.ssh._validate
  if [ "$vSTATIC_HOST" != "local" ]; then
    log.error "$0 must be run locally to interact with docker over SSH. Exiting."
    exit 1
  fi
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -p 2222 -i $(lib.ssh.path_privkey.self) -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" "$source" root@127.0.0.1:"$target"
}
lib.ssh.rsync_down.docker() {
  lib.ssh._validate
  if [ "$vSTATIC_HOST" != "local" ]; then
    log.error "$0 must be run locally. Exiting."
    exit 1
  fi
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -p 2222 -i $(lib.ssh.path_privkey.self) -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" root@127.0.0.1:"$target" "$source"
}
lib.ssh.rsync_up.remote() {
  lib.ssh._validate
  lib.ssh._require_ip
  if [ "$vSTATIC_HOST" == "remote" ]; then
    log.error "$0 must be run locally or in the dev docker container. Exiting."
    exit 1
  fi
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -i $(lib.ssh.path_privkey.self) -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" "$source" root@"$vENV_IP":"$target"
}
lib.ssh.rsync_down.remote() {
  lib.ssh._validate
  lib.ssh._require_ip
  if [ "$vSTATIC_HOST" == "remote" ]; then
    log.error "$0 must be run locally or in the dev docker container. Exiting."
    exit 1
  fi
  local source="$1"
  shift
  local target="$2"
  shift
  rsync --checksum -a -e "ssh -i $(lib.ssh.path_privkey.self) -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null" "$@" root@"$vENV_IP":"$target" "$source"
}
lib.ssh.path.self() {
  echo "$vCLI_OPT_DIR/.ssh"
}
lib.ssh.path.debian() {
  echo "/root/project/.ssh"
}
lib.ssh.path_pubkey.self() {
  echo "$(lib.ssh.path.self)/$vSTATIC_SSH_PUB_KEYNAME"
}
lib.ssh.cat_pubkey.self() {
  if [ -f "$(lib.ssh.path.self)/$vSTATIC_SSH_PUB_KEYNAME" ]; then
    cat "$(lib.ssh.path.self)/$vSTATIC_SSH_PUB_KEYNAME"
  else
    echo ""
  fi
}
lib.ssh.cat_pubkey.debian() {
  if [ -f "$(lib.ssh.path.debian)$vSTATIC_SSH_PUB_KEYNAME" ]; then
    cat "$(lib.ssh.path.debian)$vSTATIC_SSH_PUB_KEYNAME"
  else
    echo ""
  fi
}
lib.ssh.path_privkey.self() {
  if [ -f "$(lib.ssh.path.self)/$vSTATIC_SSH_RSA_KEYNAME" ]; then
    echo "$(lib.ssh.path.self)/$vSTATIC_SSH_RSA_KEYNAME"
  else
    echo ""
  fi
}
lib.ssh.path_privkey.debian() {
  if [ -f "$(lib.ssh.path.debian)$vSTATIC_SSH_RSA_KEYNAME" ]; then
    echo "$(lib.ssh.path.debian)$vSTATIC_SSH_RSA_KEYNAME"
  else
    echo ""
  fi
}
lib.ssh.path_authorized_keys.self() {
  if [ -f "$(lib.ssh.path.self)/$vSTATIC_SSH_AUTHORIZED_KEYS_FILENAME" ]; then
    echo "$(lib.ssh.path.self)/$vSTATIC_SSH_AUTHORIZED_KEYS_FILENAME"
  else
    echo ""
  fi
}
lib.ssh.path_authorized_keys.debian() {
  if [ -f "$(lib.ssh.path.debian)$vSTATIC_SSH_AUTHORIZED_KEYS_FILENAME" ]; then
    echo "$(lib.ssh.path.debian)$vSTATIC_SSH_AUTHORIZED_KEYS_FILENAME"
  else
    echo ""
  fi
}
lib.ssh.path_config.self() {
  if [ -f "$(lib.ssh.path.self)/$vSTATIC_SSH_CONFIG_FILENAME" ]; then
    echo "$(lib.ssh.path.self)/$vSTATIC_SSH_CONFIG_FILENAME"
  else
    echo ""
  fi
}
lib.ssh.path_config.debian() {
  if [ -f "$(lib.ssh.path.debian)$vSTATIC_SSH_CONFIG_FILENAME" ]; then
    echo "$(lib.ssh.path.debian)$vSTATIC_SSH_CONFIG_FILENAME"
  else
    echo ""
  fi
}
lib.ssh.build.config_file() {
  local ip="$1"
  if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log.error "can't build the ssh config file with the invalid IP: $ip"
    exit 1
  fi
  local privatekey_file="$(lib.ssh.path_privkey.self)"
  local config_file="$(lib.ssh.path_config.self)"
  {
    echo "Host 127.0.0.1"
    echo "  HostName $vSTATIC_SSH_CONF_DOCKER_HOSTNAME"
    echo "  User root"
    echo "  IdentityFile ${privatekey_file}"
    echo "  Port 2222"
    echo ""
    echo ""
    echo "Host $ip"
    echo "  HostName $vSTATIC_SSH_CONF_REMOTE_HOSTNAME"
    echo "  User root"
    echo "  IdentityFile ${privatekey_file}"
  } >"${config_file}"
  log.info "created: ${config_file}."
}
lib.ssh.extract_ip.remote() {
  #
  # We always use the ssh config file as our source of truth for the IP address.
  #
  local match_string="HostName $vSTATIC_SSH_CONF_REMOTE_HOSTNAME"
  local ip=$(grep -B 1 "$match_string" "$(lib.ssh.path_config.self)" | grep -v "$match_string" | tail -n 1 | cut -d' ' -f 2)
  if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
  else
    echo ""
  fi
}
