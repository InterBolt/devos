#!/usr/bin/env bash

set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin" || exit 1

# shellcheck source=../cache.sh
. "lib/cache.sh"

__hook__.before_file() {
  log.error "__hook__.before_file"
  return 0
}

__hook__.after_file() {
  log.error "running __hook__.after_file"
  return 0
}

__hook__.before_fn() {
  log.error "running __hook__.before_fn $1"
  return 0
}

__hook__.after_fn() {
  log.error "running __hook__.after_fn $1"
  return 0
}

__hook__.after_fn_success() {
  log.error "__hook__.after_fn_success $1"
  return 0
}

__hook__.after_fn_fails() {
  log.error "__hook__.after_fn_fails $1"
  return 0
}

__hook__.after_file_success() {
  log.error "__hook__.after_file_success"
  return 0
}

__hook__.after_file_fails() {
  log.error "__hook__.after_file_fails"
  return 0
}

vSTATIC_MY_CONFIG_ROOT=""

__test__.cache.clear() {
  log.error "cache.clear not implemented yet"
  return 0
}
__test__.cache.get() {
  log.error "cache.get not implemented yet"
  return 0
}
__test__.cache.set() {
  log.error "cache.set not implemented yet"
  return 0
}
