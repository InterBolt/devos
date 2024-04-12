#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin"

# shellcheck source=../status.sh
. "lib/status.sh"

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

vCLI_OPT_DIR=""

__test__.status.clear() {
  log.info "status.clear not implemented yet"
  return 1
}
__test__.status.get() {
  log.info "status.get not implemented yet"
  return 1
}
__test__.status.set() {
  log.info "status.set not implemented yet"
  return 1
}
