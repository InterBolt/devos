#!/usr/bin/env bash

set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin" || exit 1

# shellcheck source=../env.sh
. "lib/env.sh"

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

vCLI_OPT_DIR=""
vENTRY_BIN_FILEPATH=""
vSTATIC_ENV_FILENAME=""
vSTATIC_ENV_SH_FILENAME=""

__test__.env.generate_files() {
  log.error "env.generate_files not implemented yet"
  return 0
}
