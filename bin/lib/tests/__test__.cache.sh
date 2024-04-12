#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin"

# shellcheck source=../cache.sh
. "lib/cache.sh"

__hook__.before_file() {
  log.info "__hook__.before_file"
  return 1
}

__hook__.after_file() {
  log.info "running __hook__.after_file"
  return 1
}

__hook__.before_fn() {
  log.info "running __hook__.before_fn $1"
  return 1
}

__hook__.after_fn() {
  log.info "running __hook__.after_fn $1"
  return 1
}

__hook__.after_fn_success() {
  log.info "__hook__.after_fn_success $1"
  return 1
}

__hook__.after_fn_fails() {
  log.info "__hook__.after_fn_fails $1"
  return 1
}

__hook__.after_file_success() {
  log.info "__hook__.after_file_success"
  return 1
}

__hook__.after_file_fails() {
  log.info "__hook__.after_file_fails"
  return 1
}

vSTATIC_MY_CONFIG_ROOT=""

__test__.cache.clear() {
  log.info "cache.clear not implemented yet"
  return 1
}
__test__.cache.del() {
  log.info "cache.del not implemented yet"
  return 1
}
__test__.cache.get() {
  log.info "cache.get not implemented yet"
  return 1
}
__test__.cache.overwrite_on_empty() {
  log.info "cache.overwrite_on_empty not implemented yet"
  return 1
}
__test__.cache.prompt() {
  log.info "cache.prompt not implemented yet"
  return 1
}
__test__.cache.set() {
  log.info "cache.set not implemented yet"
  return 1
}
