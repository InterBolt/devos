#!/usr/bin/env bash

daemon_loader.log_info() {
  local message="(LOADER) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_loader.log_error() {
  local message="(LOADER) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_loader.log_warn() {
  local message="(LOADER) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_warn "${message}" "$@"
}

daemon_loader.main() {
  local tmp_solos_dir="${1}"
  daemon_loader.log_info "Loading the safe copy at: ${tmp_solos_dir}"
  sleep 2
  return 0
}
