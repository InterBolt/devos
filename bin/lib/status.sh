#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
. shared/empty.sh

vLIB_STATUS_DIR=".status"

lib.status.get() {
  local status="$1"
  if [[ -z ${status} ]]; then
    log.error "must supply a non-empty status type. Exiting."
    exit 1
  fi
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "dir: ${vOPT_PROJECT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vOPT_PROJECT_DIR}/${vLIB_STATUS_DIR}"
  local status_file="${status_dir}/${status}"
  if [[ -f "$status_file" ]]; then
    cat "${status_file}"
  else
    echo ""
  fi
}

lib.status.set() {
  local status="$1"
  if [[ -z ${status} ]]; then
    log.error "must supply a non-empty status type. Exiting."
    exit 1
  fi
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "dir: ${vOPT_PROJECT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vOPT_PROJECT_DIR}/${vLIB_STATUS_DIR}"
  mkdir -p "${status_dir}"
  local status_file="${status_dir}/${status}"
  local contents="${2:-"0"}"
  echo "$contents" >"${status_file}"
}

lib.status.clear() {
  local status="$1"
  if [[ -z ${status} ]]; then
    log.error "must supply a non-empty status type. Exiting."
    exit 1
  fi
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "dir: ${vOPT_PROJECT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vOPT_PROJECT_DIR}/${vLIB_STATUS_DIR}"
  rm -rf "${status_dir}"
}
