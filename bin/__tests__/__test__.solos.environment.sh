#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

 # shellcheck source=../solos.environment.sh
. "solos.environment.sh"

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
vENTRY_BIN_FILEPATH=""
vENV_=""
vSTATIC_ENV_FILENAME=""
vSTATIC_ENV_SH_FILENAME=""

__test__.environment.generate_env_files() {
  log.error "environment.generate_env_files not implemented yet"
  return 1
}
