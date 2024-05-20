#!/usr/bin/env bash

lib.store.del() {
  local storage_dir="$1"
  shift
  mkdir -p "${HOME}/.solos/store"
  local storage_file="store/$1"
  rm -f "${storage_file}"
}

lib.store.get() {
  local storage_dir="$1"
  shift
  mkdir -p "${HOME}/.solos/store"
  local storage_file="store/$1"
  shift
  local fallback_val="${1:-""}"
  if [[ -f ${storage_file} ]]; then
    cat "${storage_file}"
  else
    echo "${fallback_val}"
  fi
}

lib.store.set() {
  # lib.store._set "${HOME}/.solos/store" "$@"
  local storage_dir="$1"
  shift
  mkdir -p "${HOME}/.solos/store"
  local storage_file="store/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}
