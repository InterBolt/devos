#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=solos.sh
. "__shared__/static.sh"
# shellcheck source=solos.utils.sh
. "__shared__/static.sh"
# shellcheck source=__shared__/static.sh
. "__shared__/static.sh"

LIB_STATUS_DIR=".status"

status.get() {
  local status="$1"
  if [ -z "${status}" ]; then
    log.error "must supply a non-empty status type. Exiting."
    exit 1
  fi
  if [ ! -d "${vCLI_OPT_DIR}" ]; then
    log.error "dir: ${vCLI_OPT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vCLI_OPT_DIR}/${LIB_STATUS_DIR}"
  local status_file="${status_dir}/${status}"
  if [ -f "$status_file" ]; then
    cat "${status_file}"
  else
    echo ""
  fi
}
status.set() {
  local status="$1"
  if [ -z "$status" ]; then
    log.error "must supply a non-empty status type. Exiting."
    exit 1
  fi
  if [ ! -d "${vCLI_OPT_DIR}" ]; then
    log.error "dir: ${vCLI_OPT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vCLI_OPT_DIR}/${LIB_STATUS_DIR}"
  mkdir -p "${status_dir}"
  local status_file="${status_dir}/${status}"
  local contents="${2:-"0"}"
  echo "$contents" >"${status_file}"
}
status.clear() {
  local status="$1"
  if [ -z "${status}" ]; then
    log.error "must supply a non-empty status type. Exiting."
    exit 1
  fi
  if [ ! -d "${vCLI_OPT_DIR}" ]; then
    log.error "dir: ${vCLI_OPT_DIR} not found. Exiting."
    exit 1
  fi
  local status_dir="${vCLI_OPT_DIR}/${LIB_STATUS_DIR}"
  rm -rf "${status_dir}"
}