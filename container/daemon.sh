#!/usr/bin/env bash

daemon__data_dir="${HOME}/.solos/data/daemon"
daemon__pid_file="${daemon__data_dir}/pid"
daemon__logfile="${daemon__data_dir}/master.log"
daemon__pid=$$

trap "echo 'Refusing to exit the SolOS daemon process. Re-run the docker container if you need to do that.' >&2" SIGINT SIGTERM

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
log.use_custom_logfile "${daemon__logfile}"

daemon.start() {
  local found_pid=""
  local force=false
  mkdir -p "${daemon__data_dir}"
  if [[ ! -f ${daemon__logfile} ]]; then
    touch "${daemon__logfile}"
  fi

  if [[ -f ${daemon__pid_file} ]]; then
    found_pid=$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)
    if [[ ${found_pid} -eq ${daemon__pid} ]]; then
      force=true
      echo "The previous run of the daemon prevented a clean exit. Forcing a new run." >&2
    fi
    if [[ ${force} = false ]]; then
      if ps -p "${found_pid}" >/dev/null 2>&1; then
        echo "Daemon is already running with PID - ${found_pid}" >&2
        exit 1
      fi
    fi
  fi

  echo "${daemon__pid}" >"${daemon__pid_file}"
}

daemon.run() {
  log_info "Running the SolOS daemon process."
  while true; do
    log_info "Daemon is still running with PID - ${daemon__pid}"
    sleep 1
  done
}

daemon.start
daemon.run
