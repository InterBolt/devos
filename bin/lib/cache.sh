#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_CACHE_DIR=".cache"

lib.cache.del() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}/$1"
  rm -f "${tmp_filepath}"
}

lib.cache.clear() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  # shellcheck disable=SC2115
  rm -rf "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
}

lib.cache.get() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}/$1"
  if [[ -f "${tmp_filepath}" ]]; then
    cat "${tmp_filepath}"
  else
    echo ""
  fi
}

lib.cache.set() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}/$1"
  if [[ ! -f "${tmp_filepath}" ]]; then
    touch "${tmp_filepath}"
  fi
  echo "$2" >"${tmp_filepath}"
}

lib.cache.prompt() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  local input
  input="$(lib.cache.get "$1")"
  if [[ -z "${input}" ]]; then
    echo -n "Enter the $1:"
    read -r input
    if [[ -z "${input}" ]]; then
      log.error "cannot be empty. Exiting."
      exit 1
    fi
    lib.cache.set "$1" "${input}"
  fi
  lib.cache.get "$1"
}

lib.cache.overwrite_on_empty() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  local cached_val
  cached_val="$(lib.cache.get "$1")"
  local next_val="$2"
  if [[ -z "${cached_val}" ]]; then
    lib.cache.set "$1" "${next_val}"
  fi
  lib.cache.get "$1"
}
