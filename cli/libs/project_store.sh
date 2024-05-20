#!/usr/bin/env bash

lib.project_store.del() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/store"
  rm -f "${project_store_dir}/$1"
}

lib.project_store.get() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/store"
  local project_store_file="${project_store_dir}/$1"
  if [[ -f ${project_store_file} ]]; then
    cat "${project_store_file}"
  else
    echo ""
  fi
}

lib.project_store.set() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/store"
  local project_store_file="${project_store_dir}/$1"
  if [[ ! -f ${project_store_file} ]]; then
    touch "${project_store_file}"
  fi
  echo "$2" >"${project_store_file}"
}
