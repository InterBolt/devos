#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_STORE_DIR="store"

lib.store.del() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}/$1"
  rm -f "${tmp_filepath}"
}

lib.store.get() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}/$1"
  if [[ -f ${tmp_filepath} ]]; then
    cat "${tmp_filepath}"
  else
    echo ""
  fi
}

lib.store.set() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}/$1"
  if [[ ! -f ${tmp_filepath} ]]; then
    touch "${tmp_filepath}"
  fi
  echo "$2" >"${tmp_filepath}"
}

lib.store.prompt() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}"
  local input
  input="$(lib.store.get "$1")"
  if [[ -z ${input} ]]; then
    echo -n "Enter the $1:"
    read -r input
    if [[ -z ${input} ]]; then
      log.error "cannot be empty. Exiting."
      exit 1
    fi
    lib.store.set "$1" "${input}"
  fi
  lib.store.get "$1"
}

lib.store.set_on_empty() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_STORE_DIR}"
  local cached_val
  cached_val="$(lib.store.get "$1")"
  local next_val="$2"
  if [[ -z ${cached_val} ]]; then
    lib.store.set "$1" "${next_val}"
  fi
  lib.store.get "$1"
}
