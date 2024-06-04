#!/usr/bin/env bash

daemon__data_dir="${HOME}/.solos/data/daemon"
daemon__pid_file="${daemon__data_dir}/pid"
daemon__status_file="${daemon__data_dir}/status"
daemon__logfile="${daemon__data_dir}/master.log"
daemon__pid=$$

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
log.use_custom_logfile "${daemon__logfile}"

trap "log_error 'Caught and prevented an exit on SIGTERM'" SIGTERM
trap "log_error 'Caught and prevented an exit on SIGINT'" SIGINT

daemon.start() {
  echo "STARTING" >"${daemon__status_file}"
  local force=false
  mkdir -p "${daemon__data_dir}"
  if [[ ! -f ${daemon__logfile} ]]; then
    touch "${daemon__logfile}"
  fi

  if [[ -f ${daemon__pid_file} ]]; then
    local found_pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ ${found_pid} -eq ${daemon__pid} ]]; then
      echo "The previous run of the daemon prevented a clean exit. Forcing a new run." >&2
      if ps -p "${found_pid}" >/dev/null 2>&1; then
        echo "Daemon is already running with PID - ${found_pid}" >&2
        exit 1
      fi
    fi
  fi

  echo "${daemon__pid}" >"${daemon__pid_file}"
}

daemon.run() {
  echo "UP" >"${daemon__status_file}"
  while true; do
    log_info "Daemon is still running with PID - ${daemon__pid}"
    sleep 10
  done
}

if ! daemon.start; then
  log_error "Failed to start the daemon process."
  exit 1
fi

if ! daemon.run; then
  log_error "Failed to run the daemon process."
  echo "DEAD" >"${daemon__status_file}"
  exit 1
fi
