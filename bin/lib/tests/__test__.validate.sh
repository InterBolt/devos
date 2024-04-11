#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin"

 # shellcheck source=../validate.sh
. "lib/validate.sh"

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
vCLI_OPT_SERVER=""
vENV_SOLOS_ID=""
vSTATIC_BIN_LAUNCH_DIR=""
vSTATIC_DEPENDENCY_COMMANDS=""
vSTATIC_HOST=""
vSTATIC_LAUNCH_DIRNAME=""
vSTATIC_MY_CONFIG_ROOT=""
vSTATIC_REPO_SERVERS_DIR=""
vSTATIC_SERVER_TYPE_FILENAME=""

__test__.validate.checked_out_server_and_dir() {
  log.error "validate.checked_out_server_and_dir not implemented yet"
  return 1
}

__test__.validate.docker_host_running() {
  log.error "validate.docker_host_running not implemented yet"
  return 1
}

__test__.validate.throw_if_dangerous_dir() {
  log.error "validate.throw_if_dangerous_dir not implemented yet"
  return 1
}

__test__.validate.throw_if_missing_installed_commands() {
  log.error "validate.throw_if_missing_installed_commands not implemented yet"
  return 1
}

__test__.validate.throw_on_nonsolos() {
  log.error "validate.throw_on_nonsolos not implemented yet"
  return 1
}

__test__.validate.throw_on_nonsolos_dir() {
  log.error "validate.throw_on_nonsolos_dir not implemented yet"
  return 1
}

__test__.validate.validate_project_repo() {
  log.error "validate.validate_project_repo not implemented yet"
  return 1
}
