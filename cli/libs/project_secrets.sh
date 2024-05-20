#!/usr/bin/env bash

lib.project_secrets.del() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local secrets_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/secrets"
  rm -f "${secrets_dir}/$1"
}

lib.project_secrets.get() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local secrets_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/secrets"
  local secrets_file="${secrets_dir}/$1"
  if [[ -f ${secrets_file} ]]; then
    cat "${secrets_file}"
  else
    echo ""
  fi
}

lib.project_secrets.set() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local secrets_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/secrets"
  local secrets_file="${secrets_dir}/$1"
  if [[ ! -f ${secrets_file} ]]; then
    touch "${secrets_file}"
  fi
  echo "$2" >"${secrets_file}"
}
