#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_STATUS_DIR=".status"

lib.status.get() {
  local status="$1"
  if [[ -z ${status} ]]; then
    log.error "must supply a non-empty status type. Exiting."
    exit 1
  fi
  if [[ ! -d ${vCLI_OPT_DIR} ]]; then
    log.error "dir: ${vCLI_OPT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vCLI_OPT_DIR}/${LIB_STATUS_DIR}"
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
  if [[ ! -d ${vCLI_OPT_DIR} ]]; then
    log.error "dir: ${vCLI_OPT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vCLI_OPT_DIR}/${LIB_STATUS_DIR}"
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
  if [[ ! -d ${vCLI_OPT_DIR} ]]; then
    log.error "dir: ${vCLI_OPT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vCLI_OPT_DIR}/${LIB_STATUS_DIR}"
  rm -rf "${status_dir}"
}
