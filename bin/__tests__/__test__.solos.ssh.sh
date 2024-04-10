#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=../solos.ssh.sh
source "solos.ssh.sh"

testhook.before_file() {
  log.info "testhook.before_file"
}

testhook.after_file() {
  log.info "running testhook.after_file"
}

testhook.before_fn() {
  log.info "running testhook.before_fn"
}

testhook.after_fn() {
  log.info "running testhook.after_fn"
}

testhook.after_fn_success() {
  log.info "testhook.after_fn_success"
}

testhook.after_fn_fails() {
  log.info "testhook.after_fn_fails"
}

testhook.after_file_success() {
  log.info "testhook.after_file_success"
}

testhook.after_file_fails() {
  log.info "testhook.after_file_fails"
}

vCLI_OPT_DIR=""
vENV_IP=""
vSTATIC_HOST=""
vSTATIC_SSH_AUTHORIZED_KEYS_FILENAME=""
vSTATIC_SSH_CONFIG_FILENAME=""
vSTATIC_SSH_CONF_DOCKER_HOSTNAME=""
vSTATIC_SSH_CONF_REMOTE_HOSTNAME=""
vSTATIC_SSH_PUB_KEYNAME=""
vSTATIC_SSH_RSA_KEYNAME=""

__test__.ssh._require_ip() {
  log.error "ssh._require_ip not implemented yet"
  return 1
}

__test__.ssh._validate() {
  log.error "ssh._validate not implemented yet"
  return 1
}

__test__.ssh.build.config_file() {
  log.error "ssh.build.config_file not implemented yet"
  return 1
}

__test__.ssh.cat_pubkey.debian() {
  log.error "ssh.cat_pubkey.debian not implemented yet"
  return 1
}

__test__.ssh.cat_pubkey.self() {
  log.error "ssh.cat_pubkey.self not implemented yet"
  return 1
}

__test__.ssh.command.docker() {
  log.error "ssh.command.docker not implemented yet"
  return 1
}

__test__.ssh.command.remote() {
  log.error "ssh.command.remote not implemented yet"
  return 1
}

__test__.ssh.extract_ip.remote() {
  log.error "ssh.extract_ip.remote not implemented yet"
  return 1
}

__test__.ssh.path.debian() {
  log.error "ssh.path.debian not implemented yet"
  return 1
}

__test__.ssh.path.self() {
  log.error "ssh.path.self not implemented yet"
  return 1
}

__test__.ssh.path_authorized_keys.debian() {
  log.error "ssh.path_authorized_keys.debian not implemented yet"
  return 1
}

__test__.ssh.path_authorized_keys.self() {
  log.error "ssh.path_authorized_keys.self not implemented yet"
  return 1
}

__test__.ssh.path_config.debian() {
  log.error "ssh.path_config.debian not implemented yet"
  return 1
}

__test__.ssh.path_config.self() {
  log.error "ssh.path_config.self not implemented yet"
  return 1
}

__test__.ssh.path_privkey.debian() {
  log.error "ssh.path_privkey.debian not implemented yet"
  return 1
}

__test__.ssh.path_privkey.self() {
  log.error "ssh.path_privkey.self not implemented yet"
  return 1
}

__test__.ssh.path_pubkey.self() {
  log.error "ssh.path_pubkey.self not implemented yet"
  return 1
}

__test__.ssh.rsync_down.docker() {
  log.error "ssh.rsync_down.docker not implemented yet"
  return 1
}

__test__.ssh.rsync_down.remote() {
  log.error "ssh.rsync_down.remote not implemented yet"
  return 1
}

__test__.ssh.rsync_up.docker() {
  log.error "ssh.rsync_up.docker not implemented yet"
  return 1
}

__test__.ssh.rsync_up.remote() {
  log.error "ssh.rsync_up.remote not implemented yet"
  return 1
}
