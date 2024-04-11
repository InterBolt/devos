#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=../solos.cache.sh
source "solos.cache.sh"

__hook__.before_file() {
  log.info "__hook__.before_file"
}

__hook__.after_file() {
  log.info "running __hook__.after_file"
}

__hook__.before_fn() {
  log.info "running __hook__.before_fn $1"
}

__hook__.after_fn() {
  log.info "running __hook__.after_fn $1"
}

__hook__.after_fn_success() {
  log.info "__hook__.after_fn_success $1"
}

__hook__.after_fn_fails() {
  log.info "__hook__.after_fn_fails $1"
}

__hook__.after_file_success() {
  log.info "__hook__.after_file_success"
}

__hook__.after_file_fails() {
  log.info "__hook__.after_file_fails"
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
