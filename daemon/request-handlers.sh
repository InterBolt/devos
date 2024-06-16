#!/usr/bin/env bash

request_handler.extract() {
  local request_file="${1}"
  if [[ -f ${request_file} ]]; then
    local contents="$(cat "${request_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    rm -f "${request_file}"
    local requested_pid="$(echo "${contents}" | cut -d' ' -f1)"
    local requested_action="$(echo "${contents}" | cut -d' ' -f2)"
    if [[ ${requested_pid} -eq ${bin__pid} ]]; then
      echo "${requested_action}"
      return 0
    fi
    if [[ -n ${requested_pid} ]]; then
      shared.log_error "Unexpected error - the requested pid in the daemon's request file: ${request_file} is not the current daemon pid: ${bin__pid}."
      exit 1
    fi
  else
    return 1
  fi
}
request_handler.execute() {
  local request="${1}"
  case "${request}" in
  "KILL")
    shared.log_info "Request - KILL signal received. Killing the daemon process."
    bin.update_status "KILLED"
    exit 0
    ;;
  *)
    shared.log_error "Unexpected error - unknown user request ${request}"
    exit 1
    ;;
  esac
}
request_handlers.main() {
  local request="$(request_handler.extract "${bin__request_file}")"
  if [[ -n ${request} ]]; then
    shared.log_info "Request - ${request} was dispatched to the daemon."
    request_handler.execute "${request}"
  else
    shared.log_info "Request - none. Will continue to run the daemon."
  fi
}
