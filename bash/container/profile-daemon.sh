#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

profile_daemon__data_dir="${HOME}/.solos/data/daemon"
profile_daemon__users_home_dir="$(lib.home_dir_path)"
profile_daemon__status_file="${profile_daemon__data_dir}/status"
profile_daemon__pid_file="${profile_daemon__data_dir}/pid"
profile_daemon__kill_file="${profile_daemon__data_dir}/kill"
profile_daemon__log_file="${profile_daemon__data_dir}/master.log"
profile_daemon__mounted_script="/root/.solos/src/bash/container/daemon-main.sh"

. "${HOME}/.solos/src/bash/log.sh" || exit 1
. "${HOME}/.solos/src/bash/gum.sh" || exit 1

profile_daemon.suggested_action_on_error() {
  log.error "Try stopping and deleting the docker container and its associated images before reloading the shell."
  log.error "If the issue persists, please report it here: https://github.com/InterBolt/solos/issues"
}
profile_daemon.install() {
  # We only do this once so do it fast and allow lots of retries.
  local max_attempts="100"
  local attempts=0
  local timeout="0.1"

  while true; do
    local status="$(cat "${profile_daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ ${status} = "UP" ]] || [[ ${status} = "USER_KILLED" ]]; then
      break
    fi
    if [[ ${attempts} -ge ${max_attempts} ]]; then
      log.error "Unexpected error: the daemon process failed to start. It's status is: ${status}"
      profile_daemon.suggested_action_on_error
      profile.error_press_enter
    fi
    sleep "${timeout}"
    attempts=$((attempts + 1))
  done
}
profile_daemon.print_help() {
  cat <<EOF

USAGE: daemon <status|pid|logs|tail|flush|reload|kill>

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
      log.error "Unexpected error: the daemon status does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    local expect_pid="false"
    if [[ ${status} = "UP" ]] || [[ ${status} = "LAUNCHING" ]]; then
      expect_pid="true"
    fi
    if [[ -z ${pid} ]] && [[ ${expect_pid} = true ]]; then
      log.error "Unexpected error: the daemon pid does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    cat <<EOF
Daemon status: ${status}
Daemon PID: ${pid}
Daemon logfile: ${profile_daemon__log_file/\/root\//${profile_daemon__users_home_dir}\/}
EOF
    return 0
  fi
  if [[ ${1} = "pid" ]]; then
    local pid="$(cat "${profile_daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${pid} ]]; then
      log.error "Unexpected error: the daemon pid does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    echo "${pid}"
    return 0
  fi
  if [[ ${1} = "logs" ]]; then
    if [[ ! -f ${profile_daemon__log_file} ]]; then
      log.error "Unexpected error: the daemon logfile does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    cat "${profile_daemon__log_file}"
    return 0
  fi
  if [[ ${1} = "flush" ]]; then
    if [[ ! -f ${profile_daemon__log_file} ]]; then
      log.error "Unexpected error: the daemon logfile does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    if cat "${profile_daemon__log_file}"; then
      rm -f "${profile_daemon__log_file}"
      touch "${profile_daemon__log_file}"
      return 0
    else
      log.error "Failed to flush the daemon logfile."
      return 1
    fi
  fi
  if [[ ${1} = "tail" ]]; then
    shift
    local tail_args=("$@")
    if [[ ! -f ${profile_daemon__log_file} ]]; then
      log.error "Unexpected error: the daemon logfile does not exist."
      profile_daemon.suggested_action_on_error
      return 1
    fi
    tail "${tail_args[@]}" "${profile_daemon__log_file}" || return 0
    return 0
  fi
  if [[ ${1} = "kill" ]]; then
    shift
    if [[ $# -ne 0 ]]; then
      log.error "Unknown kill options: ${*}"
      return 1
    fi
    log.info "Killing. Waiting for the daemon to finish its current task."
    local pid="$(cat "${profile_daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${pid} ]]; then
      log.warn "No pid was found. Nothing to kill"
      return 0
    fi
    echo "${pid}" >"${profile_daemon__kill_file}"
    while true; do
      local status="$(cat "${profile_daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
      if [[ ${status} = "USER_KILLED" ]]; then
        break
      fi
      sleep 0.5
    done
    log.info "Killed the daemon process with PID - ${pid}"
    return 0
  fi
  if [[ ${1} = "reload" ]]; then
    log.info "Reloading. Waiting for the daemon to finish its current task."
    local pid="$(cat "${profile_daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    local running="false"
    if [[ -z ${pid} ]]; then
      log.warn "No pid was found. Will start the daemon process."
    elif ps -p "${pid}" >/dev/null; then
      running="true"
    fi
    if [[ ${running} = "true" ]]; then
      echo "${pid}" >"${profile_daemon__kill_file}"
      while true; do
        local status="$(cat "${profile_daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
        if [[ ${status} = "USER_KILLED" ]]; then
          break
        fi
        sleep 0.5
      done
      log.info "Killed the daemon process with PID - ${pid}"
    fi
    local solos_version_hash="$(git -C "/root/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo "")"
    local container_ctx="/root/.solos"
    local args=(-i -w "${container_ctx}" "${solos_version_hash}")
    local bash_args=(-c 'nohup '"${profile_daemon__mounted_script}"' >/dev/null 2>&1 &')
    if ! docker exec "${args[@]}" /bin/bash "${bash_args[@]}"; then
      log.error "Failed to reload the daemon process."
      return 1
    fi
    while true; do
      local status="$(cat "${profile_daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
      if [[ ${status} = "UP" ]]; then
        break
      fi
      sleep 0.5
    done
    log.info "Restarted the daemon process."
    return 0
  fi
  log.error "Unknown command: ${1}"
  return 1
}
