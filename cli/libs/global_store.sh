#!/usr/bin/env bash

lib.global_store.del() {
  local store_dir="${HOME}/.solos/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}

lib.global_store.get() {
  local store_dir="${HOME}/.solos/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}

lib.global_store.set() {
  local store_dir="${HOME}/.solos/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}
