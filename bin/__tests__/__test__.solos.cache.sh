#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

 # shellcheck source=../solos.cache.sh
source "solos.cache.sh"

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

vSTATIC_MY_CONFIG_ROOT=""

__test__.cache.clear() {
  log.error "cache.clear not implemented yet"
  return 1
}

__test__.cache.del() {
  log.error "cache.del not implemented yet"
  return 1
}

__test__.cache.get() {
  log.error "cache.get not implemented yet"
  return 1
}

__test__.cache.overwrite_on_empty() {
  log.error "cache.overwrite_on_empty not implemented yet"
  return 1
}

__test__.cache.prompt() {
  log.error "cache.prompt not implemented yet"
  return 1
}

__test__.cache.set() {
  log.error "cache.set not implemented yet"
  return 1
}
