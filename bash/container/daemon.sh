#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

daemon__pid=$$
daemon__phase_failure_count=0
daemon__daemon_data_dir="${HOME}/.solos/data/daemon"
daemon__pid_file="${daemon__daemon_data_dir}/pid"
daemon__status_file="${daemon__daemon_data_dir}/status"
daemon__request_file="${daemon__daemon_data_dir}/request"
daemon__log_file="${daemon__daemon_data_dir}/master.log"
daemon__users_home_dir="$(lib.home_dir_path)"
daemon__prev_pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon__report_string='Please report to https://github.com/InterBolt/solos/issues.'

trap 'rm -f "'"${daemon__pid_file}"'"' EXIT

. "${HOME}/.solos/src/bash/log.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-scrub.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-download.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-collection.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-process.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-push.sh" || exit 1

daemon.host_path() {
  local path="${1}"
  echo "${path/\/root\//${daemon__users_home_dir}\/}"
}
# Consider a more elegant way to enforce log prefixes for daemon components.
daemon.log_info() {
  local message="(MAIN) ${1} pid=\"${daemon__pid}\""
  shift
  log.info "${message}" "$@"
}
daemon.log_error() {
  local message="(MAIN) ${1} pid=\"${daemon__pid}\""
  shift
  log.error "${message}" "$@"
}
daemon.log_warn() {
  local message="(MAIN) ${1} pid=\"${daemon__pid}\""
  shift
  log.warn "${message}" "$@"
}
daemon.log_dump_info() {
  local message="(DUMP) ${1}"
  shift
  log.info_notrace "${message}" "$@"
}
daemon.log_dump_error() {
  local message="(DUMP) ${1}"
  shift
  log.error_notrace "${message}" "$@"
}
declare -A statuses=(
  ["UP"]="The daemon is running."
  ["RECOVERING"]="The daemon is recovering from a previous error."
  ["RUN_FAILED"]="The daemon plugin lifecycle failed in an unrecoverable way."
  ["START_FAILED"]="The daemon failed to start."
  ["LAUNCHING"]="The daemon is launching."
  ["KILLED"]="The daemon was killed by the user."
)
daemon.update_status() {
  local status="$1"
  if [[ -z ${statuses[${status}]} ]]; then
    daemon.log_error "Unexpected error: tried to update to an invalid status: \"${status}\""
    exit 1
  fi
  echo "${status}" >"${daemon__status_file}"
  daemon.log_info "Daemon status updated to: \"${status}\" - \"${statuses[${status}]}\""
}
daemon.save_pid() {
  if [[ -z ${daemon__pid} ]]; then
    daemon.log_error "Unexpected error: can't save an empty pid to the pid file: \"$(daemon.host_path "${daemon__pid_file}")\""
    return 1
  fi
  echo "${daemon__pid}" >"${daemon__pid_file}"
}
daemon.start() {
  if [[ -f ${daemon__pid_file} ]]; then
    daemon.log_error "Unexpected error: \"$(daemon.host_path "${daemon__pid_file}")\" already exists. This should never happen."
    return 1
  fi
  if ! daemon.save_pid; then
    daemon.log_error "Unexpected error: failed to save the daemon pid: \"${daemon__pid}\" to \"$(daemon.host_path "${daemon__pid_file}")\""
    return 1
  fi
}
daemon.archive_lifecycle() {
  local scrubbed_dir="${1}"
  local merged_download_dir="${2}"
  local merged_collection_dir="${3}"
  local processed_file="${4}"
  local pushed_dir="${5}"
  local nanoseconds="$(date +%s%N)"
  local archives_dir="${daemon__daemon_data_dir}/archives"
  local curr_archive_dir="${archives_dir}/${nanoseconds}"
  mkdir -p "${curr_archive_dir}"
  mv "${scrubbed_dir}" "${curr_archive_dir}/scrubbed" &
  mv "${merged_download_dir}" "${curr_archive_dir}/download" &
  mv "${merged_collection_dir}" "${curr_archive_dir}/collection" &
  mv "${processed_file}" "${curr_archive_dir}/processed.json" &
  mv "${pushed_dir}" "${curr_archive_dir}/pushed" &
  wait # Wait for all the moves to finish.
  local mv_return_code=$?
  if [[ ${mv_return_code} -ne 0 ]]; then
    daemon.log_error "Unexpected error: failed to archive the previous cycle. The move command returned a non-zero exit code: ${mv_return_code}"
    return 1
  fi

  # TODO: prune old archives so we don't go crazy with disk space.

  echo "${curr_archive_dir}"
}
daemon.extract_request() {
  local request_file="${1}"
  if [[ -f ${request_file} ]]; then
    local contents="$(cat "${request_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    rm -f "${request_file}"
    local target_pid="$(echo "${contents}" | cut -d' ' -f1)"
    local target_request="$(echo "${contents}" | cut -d' ' -f2)"
    if [[ ${target_pid} -eq ${daemon__pid} ]]; then
      echo "${target_request}"
    fi
    if [[ -n ${target_pid} ]]; then
      daemon.log_error "Unexpected error: the targeted pid in the daemon's request file: ${user_request_file} is not the current daemon pid: ${daemon__pid}."
      exit 1
    fi
  fi
  echo ""
}
daemon.handle_user_request() {
  local user_request="${1}"
  case "${user_request}" in
  "KILL")
    daemon.log_info "Request [handler] - user requested to kill the daemon."
    daemon.update_status "KILLED"
    exit 0
    ;;
  *)
    daemon.log_error "Unexpected error: unknown user request ${user_request}"
    exit 1
    ;;
  esac
}
daemon.dump() {
  local dump_stdout_file="${1}"
  local dump_stderr_file="${2}"
  while IFS= read -r line; do
    daemon.log_dump_info "${line}"
  done <"${dump_stdout_file}"
  while IFS= read -r line; do
    daemon.log_dump_error "${line}"
  done <"${dump_stderr_file}"
}
daemon.run() {
  local phase_kill_request_message="phase failed but will not block the daemon from running the next phase."
  while true; do
    local scrubbed_dir="$(daemon_scrub.main)"
    if [[ -z ${scrubbed_dir} ]]; then
      daemon.log_error "Unexpected error: failed to scrub the mounted volume."
      return 1
    fi
    # ------------------------------------------------------------------------------------
    #
    # DOWNLOAD PHASE:
    # let plugins download anything they need before they gain access to the data.
    #
    # ------------------------------------------------------------------------------------
    local download_phase_stdout_file="$(mktemp)"
    if ! daemon_phase_download.main >"${download_phase_stdout_file}"; then
      local return_code="$?"
      if [[ ${return_code} -eq 151 ]]; then
        return "${return_code}"
      fi
      daemon.log_error "Phase [error] - pull ${phase_kill_request_message}"
    else
      daemon.log_info "Phase [progress] - collection ran successfully."
    fi
    local download_phase_stdout="$(cat "${download_phase_stdout_file}" 2>/dev/null || echo "")"
    local download_stdout_dump="$(echo "${download_phase_stdout}" | xargs | cut -d' ' -f1)"
    local download_stderr_dump="$(echo "${download_phase_stdout}" | xargs | cut -d' ' -f2)"
    local merged_download_dir="$(echo "${download_phase_stdout}" | xargs | cut -d' ' -f3)"
    daemon.dump "${download_stdout_dump}" "${download_stderr_dump}"
    # ------------------------------------------------------------------------------------
    #
    # COLLECTOR PHASE:
    # Let plugins collect the data they need in combination with data they pulled
    # previously to generate a directory full of data.
    #
    # ------------------------------------------------------------------------------------
    local collection_phase_stdout_file="$(mktemp)"
    if ! daemon_phase_collection.main "${scrubbed_dir}" "${merged_download_dir}" >"${collection_phase_stdout_file}"; then
      local return_code="$?"
      if [[ ${return_code} -eq 151 ]]; then
        return "${return_code}"
      fi
      daemon.log_error "Phase [error] - collection ${phase_kill_request_message}"
    else
      daemon.log_info "Phase [progress] - collection ran successfully."
    fi
    local collection_phase_stdout="$(cat "${collection_phase_stdout_file}" 2>/dev/null || echo "")"
    local collection_stdout_dump="$(echo "${collection_phase_stdout}" | xargs | cut -d' ' -f1)"
    local collection_stderr_dump="$(echo "${collection_phase_stdout}" | xargs | cut -d' ' -f2)"
    local merged_collection_dir="$(echo "${collection_phase_stdout}" | xargs | cut -d' ' -f3)"
    daemon.dump "${collection_stdout_dump}" "${collection_stderr_dump}"
    # ------------------------------------------------------------------------------------
    #
    # PROCESSOR PHASE:
    # Allow all plugins to access the collected data. Any one plugin can access the data
    # generated by another plugin. This is key to allow plugins to work together.
    #
    # ------------------------------------------------------------------------------------
    local process_phase_stdout_file="$(mktemp)"
    if ! daemon_phase_process.main "${scrubbed_dir}" "${merged_download_dir}" "${merged_collection_dir}"; then
      local return_code="$?"
      if [[ ${return_code} -eq 151 ]]; then
        return "${return_code}"
      fi
      daemon.log_error "Phase [error] - process ${phase_kill_request_message}"
    else
      daemon.log_info "Phase [progress] - process ran successfully."
    fi
    local process_phase_stdout="$(cat "${process_phase_stdout_file}" 2>/dev/null || echo "")"
    local process_stdout_dump="$(echo "${process_phase_stdout}" | xargs | cut -d' ' -f1)"
    local process_stderr_dump="$(echo "${process_phase_stdout}" | xargs | cut -d' ' -f2)"
    local processed_file="$(echo "${process_phase_stdout}" | xargs | cut -d' ' -f3)"
    daemon.dump "${process_stdout_dump}" "${process_stderr_dump}"
    # ------------------------------------------------------------------------------------
    #
    # PUSH PHASE:
    # Let plugins review all the processed data across all other plugins and push it
    # to a remote location or service. Ex: a plugin might include a push that pushes
    # processed data to a RAG-as-a-service backend.
    #
    # ------------------------------------------------------------------------------------
    local push_phase_stdout_file="$(mktemp)"
    if ! daemon_phase_push.main "${processed_file}" >"${push_phase_stdout_file}"; then
      local return_code="$?"
      if [[ ${return_code} -eq 151 ]]; then
        return "${return_code}"
      fi
      daemon.log_error "Phase [error] - push ${phase_kill_request_message}"
    else
      daemon.log_info "Phase [progress] - push ran successfully."
    fi
    local push_phase_stdout="$(cat "${push_phase_stdout_file}" 2>/dev/null || echo "")"
    local push_stdout_dump="$(echo "${push_phase_stdout}" | xargs | cut -d' ' -f1)"
    local push_stderr_dump="$(echo "${push_phase_stdout}" | xargs | cut -d' ' -f2)"
    local pushed_dir="$(echo "${push_phase_stdout}" | xargs | cut -d' ' -f3)"
    daemon.dump "${push_stdout_dump}" "${push_stderr_dump}"
    # ------------------------------------------------------------------------------------
    #
    # POST RUN/ARCHIVE STUFF:
    #
    # ------------------------------------------------------------------------------------
    local archive_dir="$(daemon.archive_lifecycle "${scrubbed_dir}" "${merged_download_dir}" "${merged_collection_dir}" "${processed_file}" "${pushed_dir}")"
    if [[ ! -d ${archive_dir} ]]; then
      daemon.log_error "Unexpected error: something went wrong with the archiving step: ${archive_dir}"
      return 1
    fi
    daemon.log_info "Phase [progress] - archived phase results at \"$(daemon.host_path "${archive_dir}")\""
    daemon.log_warn "Phase [done] - waiting for the next cycle."
    daemon__phase_failure_count=0
    sleep 2
    local user_request="$(daemon.extract_request "${daemon__request_file}")"
    if [[ -n ${user_request} ]]; then
      daemon.log_info "Request [detected] - ${request}"
      daemon.handle_user_request "${user_request}"
    fi
  done
  return 0
}
daemon.main_setup() {
  if [[ ! -f ${daemon__log_file} ]]; then
    touch "${daemon__log_file}"
  fi
  log.use_custom_logfile "${daemon__log_file}"
  # The --dev flag is something we need to test the daemon in the foreground for better debugging.
  # Ensure that when supplied, our logs will be written to the console as well as the file.
  if [[ ${1} != "--dev" ]]; then
    log.use_file_only
  fi
  # Clean any old files that will interfere with the daemon's state assumptions.
  if rm -f "${daemon__pid_file}"; then
    daemon.log_info "Setup [progress] - cleared previous pid file: \"$(daemon.host_path "${daemon__pid_file}")\""
  fi
  if rm -f "${daemon__request_file}"; then
    daemon.log_info "Setup [progress] - cleared previous request file: \"$(daemon.host_path "${daemon__request_file}")\""
  fi
  # If the daemon is already running, we should abort the launch.
  # Important: abort but do not update the status. The status file should pertain
  # to the actually running daemon process, not this one.
  if [[ -n ${daemon__prev_pid} ]] && [[ ${daemon__prev_pid} -ne ${daemon__pid} ]]; then
    if ps -p "${daemon__prev_pid}" >/dev/null; then
      daemon.log_error "Unexpected error: aborting launch due to existing daemon process with pid: ${daemon__prev_pid}"
      exit 1
    fi
  fi
}
daemon.main() {
  daemon.update_status "LAUNCHING"
  if ! daemon.start; then
    daemon.log_error "Unexpected error: failed to start the daemon process."
    daemon.update_status "START_FAILED"
    lib.panics_add "daemon_failed_to_start" <<EOF
The daemon failed to start. Time of failure: $(date).
EOF
    exit 1
  fi
  daemon.update_status "UP"
  daemon.run
  local return_code=$?
  if [[ ${return_code} -eq 151 ]]; then
    daemon.log_error "Failed [error] - killing the daemon due to an exceptional error (code=151)."
    daemon.update_status "RUN_FAILED"
    lib.panics_add "daemon_plugins_failed" <<EOF
The daemon failed and exited after failing to run the installed plugins. \
Time of failure: $(date).
EOF
    exit 151
  else
    daemon.log_info "Failed [progress] - restarting the lifecycle in 5 seconds."
    daemon.update_status "RECOVERING"
    sleep 5
    daemon.main
  fi
}

daemon.main_setup
daemon.main
