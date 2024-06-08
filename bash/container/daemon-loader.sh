#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

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
  local processed_file="${1}"
  local plugins="$(daemon_shared.get_plugins)"

  daemon_loader.log_info "Will do loading for plugins: ${plugins[@]}"
}
