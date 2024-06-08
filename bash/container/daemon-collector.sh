#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_collector.log_info() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_collector.log_error() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_collector.log_warn() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_warn "${message}" "$@"
}

daemon_collector.main() {
  local scrubbed_copy="${1}"
  local collections_dir="${2}"
  local plugins="$(daemon_shared.get_plugins)"

  daemon_collector.log_info "Will do collections for plugins: ${plugins[@]}"
}
