#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

# shellcheck source=../ssh.sh
. "lib/ssh.sh"
# shellcheck source=../../shared/static.sh
. "shared/static.sh"
vDETECTED_REMOTE_IP=""
vOPT_PROJECT_DIR=""

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
__test__.ssh.build_keypairs() {
  log.error "ssh.build_keypairs not implemented yet"
  return 1
}
__test__.ssh.cat_pubkey() {
  log.error "ssh.cat_pubkey not implemented yet"
  return 1
}
__test__.ssh.command() {
  log.error "ssh.command not implemented yet"
  return 1
}
__test__.ssh.extract_ip() {
  log.error "ssh.extract_ip not implemented yet"
  return 1
}
__test__.ssh.rsync_down() {
  log.error "ssh.rsync_down not implemented yet"
  return 1
}
__test__.ssh.rsync_up() {
  log.error "ssh.rsync_up not implemented yet"
  return 1
}
__test__.ssh.extract_ip() {
  log.error "ssh.extract_ip not implemented yet"
  return 1
}
