#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_processor.log_info() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.info "${message}" "$@"
}
daemon_processor.log_error() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.error "${message}" "$@"
}
daemon_processor.log_warn() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.warn "${message}" "$@"
}

daemon_processor.main() {
  local collections_dir="${1}"
  local plugins="$(daemon_shared.get_plugins)"

  daemon_processor.log_info "Will do processing for plugins: ${plugins[@]}"
}
