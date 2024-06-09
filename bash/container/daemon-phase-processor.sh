#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_phase_processor.log_info() {
  local message="(PROCESSOR) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.info "${message}" "$@"
}
daemon_phase_processor.log_error() {
  local message="(PROCESSOR) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.error "${message}" "$@"
}
daemon_phase_processor.log_warn() {
  local message="(PROCESSOR) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.warn "${message}" "$@"
}

daemon_phase_processor.main() {
  return 0
}
