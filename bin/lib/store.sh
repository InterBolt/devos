#!/usr/bin/env bash

. shared/must-source.sh

. shared/empty.sh
. shared/empty.sh
. shared/empty.sh

vSELF_LIB_STORE_DIRNAME="store"

lib.store._del() {
  local storage_dir="$1"
  shift
  mkdir -p "${storage_dir}"
  local storage_file="${storage_dir}/$1"
  rm -f "${storage_file}"
}

lib.store._get() {
  local storage_dir="$1"
  shift
  mkdir -p "${storage_dir}"
  local storage_file="${storage_dir}/$1"
  shift
  local fallback_val="${1:-""}"
  if [[ -f ${storage_file} ]]; then
    cat "${storage_file}"
  else
    echo "${fallback_val}"
  fi
}

lib.store._set() {
  local storage_dir="$1"
  shift
  mkdir -p "${storage_dir}"
  local storage_file="${storage_dir}/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}

lib.store._prompt() {
  local storage_dir="$1"
  shift
  mkdir -p "${storage_dir}"
  local input="$(lib.store._get "${storage_dir}" "$1")"

  if [[ -z ${input} ]]; then
    input="$(pkg.gum input --cursor.foreground "#3B78FF" --prompt "Enter $1: ")"
    if [[ -z ${input} ]]; then
      log.error "Can't be empty."
      exit 1
    fi
    lib.store._set "${storage_dir}" "$1" "${input}"
  fi
  lib.store._get "${storage_dir}" "$1"
}

lib.store._set_on_empty() {
  local storage_dir="$1"
  shift
  mkdir -p "${storage_dir}"
  local cached_val
  cached_val="$(lib.store._get "${storage_dir}" "$1")"
  local next_val="$2"
  if [[ -z ${cached_val} ]]; then
    lib.store._set "${storage_dir}" "$1" "${next_val}"
  fi
  lib.store._get "${storage_dir}" "$1"
}

lib.store.global.del() {
  lib.store._del "${vSTATIC_SOLOS_ROOT}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}

lib.store.global.get() {
  lib.store._get "${vSTATIC_SOLOS_ROOT}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}

lib.store.global.set() {
  lib.store._set "${vSTATIC_SOLOS_ROOT}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}

lib.store.project.del() {
  local project_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"
  if [[ ! -d ${project_dir} ]]; then
    log.error "Store error: ${project_dir} does not exist."
    exit 1
  fi
  lib.store._del "${project_dir}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}

lib.store.project.get() {
  local project_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"
  if [[ ! -d ${project_dir} ]]; then
    log.error "Store error: ${project_dir} does not exist."
    exit 1
  fi
  lib.store._get "${project_dir}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}

lib.store.project.set() {
  local project_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"
  if [[ ! -d ${project_dir} ]]; then
    log.error "Store error: ${project_dir} does not exist."
    exit 1
  fi
  lib.store._set "${project_dir}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}

lib.store.project.prompt() {
  local project_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"
  if [[ ! -d ${project_dir} ]]; then
    log.error "Store error: ${project_dir} does not exist."
    exit 1
  fi
  lib.store._prompt "${project_dir}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}

lib.store.project.set_on_empty() {
  local project_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}"
  if [[ ! -d ${project_dir} ]]; then
    log.error "Store error: ${project_dir} does not exist."
    exit 1
  fi
  lib.store._set_on_empty "${project_dir}/${vSELF_LIB_STORE_DIRNAME}" "$@"
}
