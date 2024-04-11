#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=../solos.status.sh
source "solos.status.sh"

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

vCLI_OPT_DIR=""

__test__.status.clear() {
  log.error "status.clear not implemented yet"
  return 1
}

__test__.status.get() {
  log.error "status.get not implemented yet"
  return 1
}

__test__.status.set() {
  log.error "status.set not implemented yet"
  return 1
}
