#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_CACHE_DIR=".cache"

lib.cache.clear() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  # shellcheck disable=SC2115
  rm -rf "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
}

lib.cache.get() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}/$1"
  if [[ -f ${tmp_filepath} ]]; then
    cat "${tmp_filepath}"
  else
    echo ""
  fi
}

lib.cache.set() {
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}"
  local tmp_filepath="${vSTATIC_MY_CONFIG_ROOT}/${LIB_CACHE_DIR}/$1"
  if [[ ! -f ${tmp_filepath} ]]; then
    touch "${tmp_filepath}"
  fi
  echo "$2" >"${tmp_filepath}"
}
