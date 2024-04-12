 #!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin"

 # shellcheck source=../ssh.sh
. "lib/ssh.sh"

__hook__.before_file() {
  log.error "__hook__.before_file"
  return 1
}

__hook__.after_file() {
  log.error "running __hook__.after_file"
  return 1
}

__hook__.before_fn() {
  log.error "running __hook__.before_fn $1"
  return 1
}

__hook__.after_fn() {
  log.error "running __hook__.after_fn $1"
  return 1
}

__hook__.after_fn_success() {
  log.error "__hook__.after_fn_success $1"
  return 1
}

__hook__.after_fn_fails() {
  log.error "__hook__.after_fn_fails $1"
  return 1
}

__hook__.after_file_success() {
  log.error "__hook__.after_file_success"
  return 1
}

__hook__.after_file_fails() {
  log.error "__hook__.after_file_fails"
  return 1
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
