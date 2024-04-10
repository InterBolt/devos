#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

 # shellcheck source=../solos.precheck.sh
source "solos.precheck.sh"

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

vENTRY_BIN_DIR=""
vSTATIC_DEFAULT_SERVER=""
vSTATIC_REPO_SERVERS_DIR=""
vSTATIC_REPO_TEMPLATES_DIR=""
vSTATIC_RUNNING_REPO_ROOT=""

__test__.precheck.all() {
  log.error "precheck.all not implemented yet"
  return 1
}

__test__.precheck.launchfiles() {
  log.error "precheck.launchfiles not implemented yet"
  return 1
}

__test__.precheck.variables() {
  log.error "precheck.variables not implemented yet"
  return 1
}
