#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_STORE_DIR="store"

lib.store.del() {
  local storage_dir="$1"
  mkdir -p "${storage_dir}"
  local tmp_filepath="${storage_dir}/$1"
  rm -f "${tmp_filepath}"
}

lib.store.get() {
  local storage_dir="$1"
  mkdir -p "${storage_dir}"
  local tmp_filepath="${storage_dir}/$1"
  if [[ -f ${tmp_filepath} ]]; then
    cat "${tmp_filepath}"
  else
    echo ""
  fi
}

lib.store.set() {
  local storage_dir="$1"
  mkdir -p "${storage_dir}"
  local tmp_filepath="${storage_dir}/$1"
  if [[ ! -f ${tmp_filepath} ]]; then
    touch "${tmp_filepath}"
  fi
  echo "$2" >"${tmp_filepath}"
}

lib.store.prompt() {
  local storage_dir="$1"
  mkdir -p "${storage_dir}"
  local input
  input="$(lib.store.get "${storage_dir}" "$1")"
  if [[ -z ${input} ]]; then
    echo -n "Enter the $1:"
    read -r input
    if [[ -z ${input} ]]; then
      log.error "cannot be empty. Exiting."
      exit 1
    fi
    lib.store.set "${storage_dir}" "$1" "${input}"
  fi
  lib.store.get "${storage_dir}" "$1"
}

lib.store.set_on_empty() {
  local storage_dir="$1"
  mkdir -p "${storage_dir}"
  local cached_val
  cached_val="$(lib.store.get "$1")"
  local next_val="$2"
  if [[ -z ${cached_val} ]]; then
    lib.store.set "${storage_dir}" "$1" "${next_val}"
  fi
  lib.store.get "${storage_dir}" "$1"
}

lib.store.global.del() {
  lib.store.del "${vSTATIC_SOLOS_ROOT}/${LIB_STORE_DIR}"
}

lib.store.global.get() {
  lib.store.get "${vSTATIC_SOLOS_ROOT}/${LIB_STORE_DIR}"
}

lib.store.global.set() {
  lib.store.set "${vSTATIC_SOLOS_ROOT}/${LIB_STORE_DIR}"
}

lib.store.global.prompt() {
  lib.store.prompt "${vSTATIC_SOLOS_ROOT}/${LIB_STORE_DIR}"
}

lib.store.global.set_on_empty() {
  lib.store.set_on_empty "${vSTATIC_SOLOS_ROOT}/${LIB_STORE_DIR}"
}

lib.store.project.del() {
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "Store error: ${vOPT_PROJECT_DIR} does not exist."
    exit 1
  fi
  lib.store.del "${vOPT_PROJECT_DIR}/${LIB_STORE_DIR}"
}

lib.store.project.get() {
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "Store error: ${vOPT_PROJECT_DIR} does not exist."
    exit 1
  fi
  lib.store.get "${vOPT_PROJECT_DIR}/${LIB_STORE_DIR}"
}

lib.store.project.set() {
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "Store error: ${vOPT_PROJECT_DIR} does not exist."
    exit 1
  fi
  lib.store.set "${vOPT_PROJECT_DIR}/${LIB_STORE_DIR}"
}

lib.store.project.prompt() {
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "Store error: ${vOPT_PROJECT_DIR} does not exist."
    exit 1
  fi
  lib.store.prompt "${vOPT_PROJECT_DIR}/${LIB_STORE_DIR}"
}

lib.store.project.set_on_empty() {
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "Store error: ${vOPT_PROJECT_DIR} does not exist."
    exit 1
  fi
  lib.store.set_on_empty "${vOPT_PROJECT_DIR}/${LIB_STORE_DIR}"
}
