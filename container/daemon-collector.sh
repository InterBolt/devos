#!/usr/bin/env bash

daemon_collector.log_info() {
  local message="(COLLECTOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_collector.log_error() {
  local message="(COLLECTOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_collector.log_warn() {
  local message="(COLLECTOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_warn "${message}" "$@"
}

daemon_collector.main() {
  local tmp_solos_dir="${1}"
  daemon_collector.log_info "Collecting with the safe copy at: ${tmp_solos_dir}"
  sleep 2
  return 0
}
