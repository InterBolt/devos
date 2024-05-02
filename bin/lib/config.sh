#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh
# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../bin.sh
. shared/empty.sh

lib.config.del() {
  local config_dir="${vSTATIC_SOLOS_CONFIG_DIR}"
  local key="${1:-""}"
  if [[ -z ${key} ]]; then
    log.error "Unexpected error: key can't be empty"
    exit 1
  fi
  if [[ ! -d ${vSTATIC_SOLOS_CONFIG_DIR} ]]; then
    log.error "Unexpected error: ${vSTATIC_SOLOS_CONFIG_DIR} doesn't exist."
    exit 1
  fi
  if [[ -d ${vSTATIC_SOLOS_CONFIG_DIR}/${key} ]]; then
    log.error "Unexpected error: ${vSTATIC_SOLOS_CONFIG_DIR}/${key} is a directory."
    exit 1
  fi
  rm -f "${vSTATIC_SOLOS_CONFIG_DIR}/${key}"
}

lib.config.set() {
  local config_dir="${vSTATIC_SOLOS_CONFIG_DIR}"
  local key="${1:-""}"
  local value="${2:-""}"
  if [[ -z ${key} ]]; then
    log.error "Unexpected error: key can't be empty"
    exit 1
  fi
  if [[ ! -d ${vSTATIC_SOLOS_CONFIG_DIR} ]]; then
    log.error "Unexpected error: ${vSTATIC_SOLOS_CONFIG_DIR} doesn't exist."
    exit 1
  fi
  if [[ -d ${vSTATIC_SOLOS_CONFIG_DIR}/${key} ]]; then
    log.error "Unexpected error: ${vSTATIC_SOLOS_CONFIG_DIR}/${key} is a directory."
    exit 1
  fi
  if [[ ! -f ${vSTATIC_SOLOS_CONFIG_DIR}/${key} ]]; then
    touch "${vSTATIC_SOLOS_CONFIG_DIR}/${key}"
  fi
  echo "${value:-""}" >"${vSTATIC_SOLOS_CONFIG_DIR}/${key}"
}

lib.config.get() {
  local config_dir="${vSTATIC_SOLOS_CONFIG_DIR}"
  local key="${1:-""}"
  if [[ -z ${key} ]]; then
    log.error "Unexpected error: key can't be empty"
    exit 1
  fi
  if [[ ! -d ${vSTATIC_SOLOS_CONFIG_DIR} ]]; then
    log.error "Unexpected error: ${vSTATIC_SOLOS_CONFIG_DIR} doesn't exist."
    exit 1
  fi
  if [[ -d ${vSTATIC_SOLOS_CONFIG_DIR}/${key} ]]; then
    log.error "Unexpected error: ${vSTATIC_SOLOS_CONFIG_DIR}/${key} is a directory."
    exit 1
  fi
  echo "${vSTATIC_SOLOS_CONFIG_DIR}/${key}"
}
