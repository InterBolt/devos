#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

 # shellcheck source=../solos.validate.sh
source "solos.validate.sh"

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
vCLI_OPT_SERVER=""
vENV_SOLOS_ID=""
vSTATIC_BIN_LAUNCH_DIR=""
vSTATIC_DEPENDENCY_COMMANDS=""
vSTATIC_HOST=""
vSTATIC_LAUNCH_DIRNAME=""
vSTATIC_MY_CONFIG_ROOT=""
vSTATIC_REPO_SERVERS_DIR=""
vSTATIC_SERVER_TYPE_FILENAME=""

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
