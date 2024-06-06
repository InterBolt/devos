#!/usr/bin/env bash

daemon_processor.log_info() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_processor.log_error() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_processor.log_warn() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_warn "${message}" "$@"
}

daemon_processor.main() {
  local tmp_solos_dir="${1}"
  daemon_processor.log_info "Processing the safe copy at: ${tmp_solos_dir}"
  sleep 2
  return 0
}
