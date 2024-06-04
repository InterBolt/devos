#!/usr/bin/env bash

profile_daemon__data_dir="${HOME}/.solos/data/daemon"
profile_daemon__status_file="${profile_daemon__data_dir}/status"
profile_daemon__pid_file="${profile_daemon__data_dir}/pid"
profile_daemon__logfile="${profile_daemon__data_dir}/master.log"

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1

profile_daemon.suggested_action_on_error() {
  log_error "Try stopping and deleting the docker container and its associated images before restarting the shell."
  log_error "If the issue persists, please report it here: https://github.com/InterBolt/solos/issues"
}

profile_daemon.install() {
  # We only do this once so do it fast and allow lots of retries.
  local max_attempts=30
  local attempts=0
  local timeout="0.1"

  while true; do
    local status="$(cat "${profile_daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ ${status} = "UP" ]]; then
      break
    fi
    if [[ ${attempts} -ge ${max_attempts} ]]; then
      log_error "Unexpected error: the daemon process failed to start. It's status is: ${status}"
      profile_daemon.suggested_action_on_error
      profile.error_press_enter
    fi
    sleep "${timeout}"
    attempts=$((attempts + 1))
  done
}
profile_daemon.print_help() {
  cat <<EOF

USAGE: daemon <status|pid|logs|tail|restart>

DESCRIPTION:

Some utility commands to see what's going on with the daemon process.

EOF
}
profile_daemon.main() {
  if [[ $# -eq 0 ]]; then
    profile_daemon.print_help
    return 0
  fi
  if profile.is_help_cmd "$1"; then
    profile_daemon.print_help
    return 0
  fi
  if [[ ${1} = "status" ]]; then
    local status="$(cat "${profile_daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    local pid="$(cat "${profile_daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${status} ]]; then
      log_error "Unexpected error: the daemon status does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    if [[ -z ${pid} ]]; then
      log_error "Unexpected error: the daemon pid does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    cat <<EOF
Daemon status: ${status}
Daemon PID: ${pid}
Daemon logfile: ${profile_daemon__logfile}
EOF
    return 0
  fi
  if [[ ${1} = "pid" ]]; then
    local pid="$(cat "${profile_daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${pid} ]]; then
      log_error "Unexpected error: the daemon pid does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    echo "${pid}"
    return 0
  fi
  if [[ ${1} = "logs" ]]; then
    if [[ ! -f ${profile_daemon__logfile} ]]; then
      log_error "Unexpected error: the daemon logfile does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    cat "${profile_daemon__logfile}"
    return 0
  fi
  if [[ ${1} = "tail" ]]; then
    if [[ ! -f ${profile_daemon__logfile} ]]; then
      log_error "Unexpected error: the daemon logfile does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    tail -f "${profile_daemon__logfile}" || return 0
  fi
  if [[ ${1} = "restart" ]]; then
    local pid="$(cat "${profile_daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${pid} ]]; then
      log_error "Unexpected error: the daemon pid does not exist. Are you sure it's running?"
      profile_daemon.suggested_action_on_error
      return 1
    fi
    if ! kill -9 "${pid}"; then
      log_error "Unexpected error: failed to kill the daemon process with PID - ${pid}"
      profile_daemon.suggested_action_on_error
      return 1
    fi
    log_info "Killed the daemon process with PID - ${pid}"
    local solos_version_hash="$(git -C "/root/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo "")"
    local container_ctx="/root/.solos"
    local args=(-i -w "${container_ctx}" "${solos_version_hash}")
    local bash_args=(-c 'nohup /root/.solos/src/container/daemon.sh >/dev/null 2>&1 &')
    if ! docker exec "${args[@]}" /bin/bash "${bash_args[@]}"; then
      log_error "Failed to restart the daemon process."
      return 1
    fi
    log_info "Restarted the daemon process."
    return 0
  fi
  log_error "Unknown command: ${1}"
  return 1
}
