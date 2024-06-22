#!/usr/bin/env bash

daemon__data_dir="${HOME}/.solos/data/daemon"
daemon__status_file="${daemon__data_dir}/status"
daemon__pid_file="${daemon__data_dir}/pid"
daemon__request_file="${daemon__data_dir}/request"
daemon__log_file="${daemon__data_dir}/master.log"
daemon__mounted_script="/root/.solos/repo/src/daemon/daemon.sh"

daemon.suggested_action_on_error() {
  shell.log_error "Try stopping and deleting the docker container and its associated images before reloading the shell."
  shell.log_error "If the issue persists, please report it here: https://github.com/InterBolt/solos/issues"
}
daemon.install() {
  # We only do this once so do it fast and allow lots of retries.
  local max_attempts="100"
  local attempts=0
  local timeout="0.1"

  while true; do
    local status="$(cat "${daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ ${status} = "UP" ]] || [[ ${status} = "KILLED" ]] || [[ ${status} = "RUN_FAILED" ]] || [[ ${status} = "START_FAILED" ]]; then
      break
    fi
    if [[ ${attempts} -ge ${max_attempts} ]]; then
      shell.log_error "Unexpected error: the daemon process failed to start. It's status is: ${status}"
      daemon.suggested_action_on_error
      lib.enter_to_exit
    fi
    sleep "${timeout}"
    attempts=$((attempts + 1))
  done
}
daemon.print_help() {
  cat <<EOF

USAGE: daemon <status|pid|tail|flush|reload|kill>

DESCRIPTION:

Some utility commands to manage the daemon process.

COMMANDS:

status      - Show the status of the daemon process.
pid         - Show the PID of the daemon process.
tail        - A wrapper around the tail command to view the daemon's logs.
flush       - Prints the logs to stdout before wiping the file.
reload      - Restart the daemon process.
kill        - Kill the daemon process.
foreground  - Run the daemon in the foreground.

NOTES:

(1) The \`kill\` and  and \`reload\` will always wait for the daemon to finish running all of the remaining plugin phases. \
If you really need to stop the daemon immediately, you can do something like kill -9 "\$(daemon pid)". Not recommended unless it's an absolute emergency.
(2) Take care when using the \`flush\` command. Permanently losing logs can be a pain when debugging.

EOF
}
daemon.cmd() {
  if [[ $# -eq 0 ]]; then
    daemon.print_help
    return 0
  fi
  if lib.is_help_cmd "$1"; then
    daemon.print_help
    return 0
  fi
  if [[ ${1} = "status" ]]; then
    local status="$(cat "${daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    local pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${status} ]]; then
      shell.log_error "Unexpected error: the daemon status does not exist."
      daemon.suggested_action_on_error
      return 1
    fi
    local expect_pid="false"
    if [[ ${status} = "UP" ]] || [[ ${status} = "LAUNCHING" ]]; then
      expect_pid="true"
    fi
    if [[ -z ${pid} ]] && [[ ${expect_pid} = true ]]; then
      shell.log_error "Unexpected error: the daemon pid does not exist."
      daemon.suggested_action_on_error
      return 1
    fi
    cat <<EOF
Daemon status: ${status}
Daemon PID: ${pid}
Daemon logfile: ${daemon__log_file/\/root\//${shell__users_home_dir}\/}
EOF
    return 0
  fi
  if [[ ${1} = "pid" ]]; then
    local pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${pid} ]]; then
      shell.log_error "Unexpected error: the daemon pid does not exist."
      daemon.suggested_action_on_error
      return 1
    fi
    echo "${pid}"
    return 0
  fi
  if [[ ${1} = "flush" ]]; then
    if [[ ! -f ${daemon__log_file} ]]; then
      shell.log_error "Unexpected error: the daemon logfile does not exist."
      daemon.suggested_action_on_error
      return 1
    fi
    if cat "${daemon__log_file}"; then
      rm -f "${daemon__log_file}"
      touch "${daemon__log_file}"
      return 0
    else
      shell.log_error "Failed to flush the daemon logfile."
      return 1
    fi
  fi
  if [[ ${1} = "tail" ]]; then
    shift
    local tail_args=("$@")
    if [[ ! -f ${daemon__log_file} ]]; then
      shell.log_error "Unexpected error: the daemon logfile does not exist."
      daemon.suggested_action_on_error
      return 1
    fi
    tail "${tail_args[@]}" "${daemon__log_file}" || return 0
    return 0
  fi
  if [[ ${1} = "kill" ]]; then
    shift
    if [[ $# -ne 0 ]]; then
      shell.log_error "Unknown kill options: ${*}"
      return 1
    fi
    shell.log_info "Killing. Waiting for the daemon to finish its current task."
    local pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ -z ${pid} ]]; then
      shell.log_warn "No pid was found. Nothing to kill"
      return 0
    fi
    echo "${pid} KILL" >"${daemon__request_file}"
    while true; do
      local status="$(cat "${daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
      if [[ ${status} = "KILLED" ]]; then
        break
      fi
      sleep 0.5
    done
    shell.log_info "Killed the daemon process with PID - ${pid}"
    return 0
  fi
  if [[ ${1} = "reload" ]]; then
    shell.log_info "Reloading. Waiting for the daemon to finish its cycle."
    local pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    local pid_exists="false"
    if [[ -z ${pid} ]]; then
      shell.log_warn "No pid was found. Will start the daemon process."
    elif ps -p "${pid}" >/dev/null; then
      pid_exists="true"
    fi
    if [[ ${pid_exists} = "true" ]]; then
      echo "${pid}" >"${daemon__kill_file}"
      while true; do
        local status="$(cat "${daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
        if [[ ${status} = "KILLED" ]]; then
          break
        fi
        sleep 0.5
      done
      shell.log_info "Killed the daemon process with PID - ${pid}"
    fi
    local repo_commit="$(git -C "/root/.solos/repo" rev-parse --short HEAD | cut -c1-7 || echo "")"
    local container_ctx="/root/.solos"
    local args=(-i -w "${container_ctx}" "${repo_commit}")
    local bash_args=(-c 'nohup '"${daemon__mounted_script}"' >/dev/null 2>&1 &')
    if ! docker exec "${args[@]}" /bin/bash "${bash_args[@]}"; then
      shell.log_error "Failed to reload the daemon process."
      return 1
    fi
    while true; do
      local status="$(cat "${daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
      if [[ ${status} = "UP" ]]; then
        break
      fi
      sleep 0.5
    done
    shell.log_info "Restarted the daemon process."
    return 0
  fi
  if [[ ${1} = "foreground" ]]; then
    shell.log_info "Will run in foreground after the daemon completes its current cycle."
    local pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    local pid_exists="false"
    if [[ -z ${pid} ]]; then
      shell.log_warn "No pid was found. Will start the daemon process."
    elif ps -p "${pid}" >/dev/null; then
      pid_exists="true"
    fi
    if [[ ${pid_exists} = "true" ]]; then
      echo "${pid}" >"${daemon__kill_file}"
      while true; do
        local status="$(cat "${daemon__status_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
        if [[ ${status} = "KILLED" ]] || [[ ${status} = "RUN_FAILED" ]] || [[ ${status} = "START_FAILED" ]]; then
          shell.log_info "The the daemon process with PID - ${pid} is no longer running."
          break
        fi
        sleep 0.5
      done
    fi
    local repo_commit="$(git -C "/root/.solos/repo" rev-parse --short HEAD | cut -c1-7 || echo "")"
    local container_ctx="/root/.solos"
    local docker_exec_args=(-it -w "${container_ctx}" "${repo_commit}")
    local bash_args=(-i -c "${daemon__mounted_script}")
    shell.log_info "Launching the daemon process in the foreground."
    if ! docker exec "${docker_exec_args[@]}" /bin/bash "${bash_args[@]}"; then
      shell.log_error "Failed to reload the daemon process."
      return 1
    fi
  fi
  shell.log_error "Unknown command: ${1}"
  return 1
}
