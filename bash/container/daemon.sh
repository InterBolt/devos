#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

daemon__pid=$$
daemon__remaining_retries=5
daemon__daemon_data_dir="${HOME}/.solos/data/daemon"
daemon__pid_file="${daemon__daemon_data_dir}/pid"
daemon__status_file="${daemon__daemon_data_dir}/status"
daemon__request_file="${daemon__daemon_data_dir}/request"
daemon__log_file="${daemon__daemon_data_dir}/master.log"
daemon__users_home_dir="$(lib.home_dir_path)"
daemon__prev_pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"

trap 'rm -f "'"${daemon__pid_file}"'"' EXIT

. "${HOME}/.solos/src/bash/log.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-task-scrub.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-download.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-collection.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-process.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-firejailed-phase-push.sh" || exit 1

daemon.host_path() {
  local path="${1}"
  echo "${path/\/root\//${daemon__users_home_dir}\/}"
}
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
declare -A statuses=(
  ["UP"]="The daemon is running."
  ["RECOVERING"]="The daemon is recovering from a nonfatal error."
  ["RUN_FAILED"]="The daemon plugin lifecycle failed in an unrecoverable way and stopped running to limit damage."
  ["START_FAILED"]="The daemon failed to start up."
  ["LAUNCHING"]="The daemon is starting up."
  ["KILLED"]="The user killed the daemon process."
)
daemon.update_status() {
  local status="$1"
  if [[ -z ${statuses[${status}]} ]]; then
    daemon.log_error "Unexpected error - tried to update to an invalid status: \"${status}\""
    exit 1
  fi
  echo "${status}" >"${daemon__status_file}"
  daemon.log_info "Status - updated to: \"${status}\" - \"${statuses[${status}]}\""
}
daemon.archive() {
  local scrubbed_dir="${1}"
  local merged_download_dir="${2}"
  local merged_collection_dir="${3}"
  local merged_processed_dir="${4}"
  local merged_configure_dir="${5}"
  local processed_file="${6}"
  local merged_push_dir="${7}"
  local nanoseconds="$(date +%s%N)"
  local archives_dir="${daemon__daemon_data_dir}/archives"
  local curr_archive_dir="${archives_dir}/${nanoseconds}"
  mkdir -p "${curr_archive_dir}"
  mv "${scrubbed_dir}" "${curr_archive_dir}/scrubbed" &
  mv "${merged_download_dir}" "${curr_archive_dir}/download" &
  mv "${merged_collection_dir}" "${curr_archive_dir}/collection" &
  mv "${merged_processed_dir}" "${curr_archive_dir}/processed" &
  mv "${merged_configure_dir}" "${curr_archive_dir}/configure" &
  mv "${processed_file}" "${curr_archive_dir}/processed.json" &
  mv "${merged_push_dir}" "${curr_archive_dir}/pushed" &
  wait # Wait for all the moves to finish.
  local mv_return_code=$?
  if [[ ${mv_return_code} -ne 0 ]]; then
    daemon.log_error "Unexpected error - failed to archive the previous cycle. The move commands returned a non-zero exit code: ${mv_return_code}"
    return 1
  fi
  local archives=($(ls -t "${archives_dir}"))
  local archives_to_delete=("${archives[@]:5}")
  for archive in "${archives_to_delete[@]}"; do
    rm -rf "${archives_dir}/${archive}"
  done
  echo "${curr_archive_dir}"
}
daemon.extract_request() {
  local request_file="${1}"
  if [[ -f ${request_file} ]]; then
    local contents="$(cat "${request_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    rm -f "${request_file}"
    local requested_pid="$(echo "${contents}" | cut -d' ' -f1)"
    local requested_action="$(echo "${contents}" | cut -d' ' -f2)"
    if [[ ${requested_pid} -eq ${daemon__pid} ]]; then
      echo "${requested_action}"
      return 0
    fi
    if [[ -n ${requested_pid} ]]; then
      daemon.log_error "Unexpected error - the requested pid in the daemon's request file: ${request_file} is not the current daemon pid: ${daemon__pid}."
      exit 1
    fi
  else
    return 1
  fi
}
daemon.handle_request() {
  local request="${1}"
  case "${request}" in
  "KILL")
    daemon.log_info "Request - KILL signal received. Killing the daemon process."
    daemon.update_status "KILLED"
    exit 0
    ;;
  *)
    daemon.log_error "Unexpected error - unknown user request ${request}"
    exit 1
    ;;
  esac
}
daemon.update_configs() {
  local merged_configure_dir="${1}"
  local solos_plugin_names=($(daemon_shared.get_solos_plugin_names))
  local user_plugin_names=($(daemon_shared.get_user_plugin_names))
  local precheck_plugin_names=($(daemon_shared.get_precheck_plugin_names))
  local plugin_names=("${precheck_plugin_names[@]}" "${solos_plugin_names[@]}" "${user_plugin_names[@]}")
  local plugin_paths=($(daemon_shared.plugin_names_to_paths "${plugin_names[@]}"))
  for plugin_path in "${plugin_paths[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    local plugin_dir="$(dirname "${plugin_path}")"
    local config_path="${plugin_dir}/solos.json"
    local updated_config_path="${merged_configure_dir}/${plugin_name}-solos.json"
    if [[ -f ${updated_config_path} ]]; then
      rm -f "${config_path}"
      cp "${updated_config_path}" "${config_path}"
      daemon.log_info "Config - updated the config at ${config_path}."
    fi
  done
}
daemon.dump() {
  local dump_stdout_file="${1}"
  local dump_stderr_file="${2}"
  echo "[DUMP:STDOUT]" >>"${daemon__log_file}"
  while IFS= read -r line; do
    echo "${line}" >>"${daemon__log_file}"
  done <"${dump_stdout_file}"
  echo "[DUMP:STDERR]" >>"${daemon__log_file}"
  while IFS= read -r line; do
    echo "${line}" >>"${daemon__log_file}"
  done <"${dump_stderr_file}"
}
daemon.run_plugins() {
  local plugins=("${@}")
  local scrubbed_dir="$(daemon_task_scrub.main)"
  if [[ -z ${scrubbed_dir} ]]; then
    daemon.log_error "Unexpected error - failed to scrub the mounted volume."
    return 1
  fi
  # ------------------------------------------------------------------------------------
  #
  # CONFIGURE PHASE:
  # Allow plugins to create a default config if none was provided, or modify the existing
  # one if it detects abnormalities.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! daemon_firejailed_phase_configure.main "${plugins[@]}" >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    daemon.log_error "Nonfatal - the configure phase failed with return code ${return_code}."
  else
    daemon.log_info "Progress - the configure phase ran successfully."
  fi
  local configure_phase_stdout="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local configure_stdout_dump="$(lib.line_to_args "0")"
  local configure_stderr_dump="$(lib.line_to_args "1")"
  local merged_configure_dir="$(lib.line_to_args "2")"
  daemon.dump "${configure_stdout_dump}" "${configure_stderr_dump}"
  daemon.update_configs "${merged_configure_dir}"
  # ------------------------------------------------------------------------------------
  #
  # DOWNLOAD PHASE:
  # let plugins download anything they need before they gain access to the data.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! daemon_firejailed_phase_download.main \
    "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    daemon.log_error "Nonfatal - the download phase failed with return code ${return_code}."
  else
    daemon.log_info "Progress - the download phase ran successfully."
  fi
  local download_phase_stdout="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local download_stdout_dump="$(lib.line_to_args "0")"
  local download_stderr_dump="$(lib.line_to_args "1")"
  local merged_download_dir="$(lib.line_to_args "2")"
  daemon.dump "${download_stdout_dump}" "${download_stderr_dump}"
  # ------------------------------------------------------------------------------------
  #
  # COLLECTOR PHASE:
  # Let plugins collect the data they need in combination with data they pulled
  # previously to generate a directory full of data.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! daemon_firejailed_phase_collection.main \
    "${scrubbed_dir}" "${merged_download_dir}" "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    daemon.log_error "Nonfatal - the collection phase failed with return code ${return_code}."
  else
    daemon.log_info "Progress - the collection phase ran successfully."
  fi
  local collection_phase_stdout="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local collection_stdout_dump="$(lib.line_to_args "0")"
  local collection_stderr_dump="$(lib.line_to_args "1")"
  local merged_collection_dir="$(lib.line_to_args "2")"
  daemon.dump "${collection_stdout_dump}" "${collection_stderr_dump}"
  # ------------------------------------------------------------------------------------
  #
  # PROCESSOR PHASE:
  # Allow all plugins to access the collected data. Any one plugin can access the data
  # generated by another plugin. This is key to allow plugins to work together.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! daemon_firejailed_phase_process.main \
    "${scrubbed_dir}" "${merged_download_dir}" "${merged_collection_dir}" "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    daemon.log_error "Nonfatal - the process phase failed with return code ${return_code}."
  else
    daemon.log_info "Progress - the process phase ran successfully."
  fi
  local process_phase_stdout="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local process_stdout_dump="$(lib.line_to_args "0")"
  local process_stderr_dump="$(lib.line_to_args "1")"
  local merged_processed_dir="$(lib.line_to_args "2")"
  daemon.dump "${process_stdout_dump}" "${process_stderr_dump}"
  # ------------------------------------------------------------------------------------
  #
  # PUSH PHASE:
  # Let plugins review all the processed data across all other plugins and push it
  # to a remote location or service. Ex: a plugin might include a push that pushes
  # processed data to a RAG-as-a-service backend.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! daemon_firejailed_phase_push.main \
    "${merged_processed_dir}" "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    daemon.log_error "Nonfatal - the push phase failed with return code ${return_code}."
  else
    daemon.log_info "Progress - the push phase ran successfully."
  fi
  local push_phase_stdout="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local push_stdout_dump="$(lib.line_to_args "0")"
  local push_stderr_dump="$(lib.line_to_args "1")"
  local merged_push_dir="$(lib.line_to_args "2")"
  daemon.dump "${push_stdout_dump}" "${push_stderr_dump}"
  # ------------------------------------------------------------------------------------
  #
  # POST RUN/ARCHIVE STUFF:
  #
  # ------------------------------------------------------------------------------------
  local archive_dir="$(
    daemon.archive \
      "${scrubbed_dir}" \
      "${merged_download_dir}" \
      "${merged_collection_dir}" \
      "${merged_processed_dir}" \
      "${merged_configure_dir}" \
      "${processed_file}" \
      "${merged_push_dir}"
  )"
  if [[ ! -d ${archive_dir} ]]; then
    daemon.log_error "Unexpected error - something went wrong with the archiving step: ${archive_dir}"
    return 1
  fi
  echo "${archive_dir}"
}
daemon.run() {
  local is_precheck=true
  while true; do
    plugins=()
    if [[ ${is_precheck} = true ]]; then
      local precheck_plugin_names="$(daemon_shared.get_precheck_plugin_names)"
      plugins=($(daemon_shared.plugin_names_to_paths "${precheck_plugin_names[@]}"))
    else
      local solos_plugin_names="$(daemon_shared.get_solos_plugin_names)"
      local user_plugin_names="$(daemon_shared.get_user_plugin_names)"
      local solos_plugins=($(daemon_shared.plugin_names_to_paths "${solos_plugin_names[@]}"))
      local user_plugins=($(daemon_shared.plugin_names_to_paths "${user_plugin_names[@]}"))
      plugins=("${solos_plugins[@]}" "${user_plugins[@]}")
    fi
    [[ ${is_precheck} = true ]] && is_precheck=false || is_precheck=true
    if [[ ${#plugins[@]} -eq 0 ]]; then
      daemon.log_warn "Halting - no plugins were found. Waiting 10 seconds before the next run."
      sleep 10
      continue
    fi
    daemon.log_info "Progress - starting a new cycle."
    daemon.run_plugins "${plugins[@]}"
    daemon.log_info "Progress - archived phase results at \"$(daemon.host_path "${archive_dir}")\""
    daemon.log_warn "Done - waiting for the next cycle."
    daemon__remaining_retries=5
    sleep 2
    local request="$(daemon.extract_request "${daemon__request_file}")"
    if [[ -n ${request} ]]; then
      daemon.log_info "Request - ${request} was dispatched to the daemon."
      daemon.handle_request "${request}"
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
    daemon.log_info "Setup - cleared previous pid file: \"$(daemon.host_path "${daemon__pid_file}")\""
  fi
  if rm -f "${daemon__request_file}"; then
    daemon.log_info "Setup - cleared previous request file: \"$(daemon.host_path "${daemon__request_file}")\""
  fi
  # If the daemon is already running, we should abort the launch.
  # Important: abort but do not update the status. The status file should pertain
  # to the actually running daemon process, not this one.
  if [[ -n ${daemon__prev_pid} ]] && [[ ${daemon__prev_pid} -ne ${daemon__pid} ]]; then
    if ps -p "${daemon__prev_pid}" >/dev/null; then
      daemon.log_error "Unexpected error - aborting launch due to existing daemon process with pid: ${daemon__prev_pid}"
      exit 1
    fi
  fi
}
daemon.main() {
  daemon.update_status "LAUNCHING"
  if [[ -f ${daemon__pid_file} ]]; then
    daemon.log_error "Unexpected error - \"$(daemon.host_path "${daemon__pid_file}")\" already exists. This should never happen."
    daemon.update_status "START_FAILED"
    lib.panics_add "daemon_pid_file_already_exists" <<EOF
The daemon failed to start up because the pid file already exists. Time of failure: $(date).
EOF
    return 1
  fi
  if [[ -z ${daemon__pid} ]]; then
    daemon.log_error "Unexpected error - can't save an empty pid to the pid file: \"$(daemon.host_path "${daemon__pid_file}")\""
    daemon.update_status "START_FAILED"
    lib.panics_add "daemon_empty_pid" <<EOF
The daemon failed to start up because it could not determine it's PID. Time of failure: $(date).
EOF 
    return 1
  fi
  echo "${daemon__pid}" >"${daemon__pid_file}"
  daemon.update_status "UP"
  daemon.run
  local return_code=$?
  if [[ ${return_code} -eq 151 ]]; then
    daemon.log_error "Fatal - killing the daemon due to a custom error code: 151."
    daemon.update_status "RUN_FAILED"
    lib.panics_add "daemon_plugins_failed" <<EOF
The daemon failed and exited as a result of a SOLOS_PANIC signal from a running plugin. \
Time of failure: $(date).
EOF
    exit 151
  else
    daemon__remaining_retries=$((daemon__remaining_retries - 1))
    if [[ ${daemon__remaining_retries} -eq 0 ]]; then
      daemon.log_error "Fatal - killing the daemon due to too many failures."
      daemon.update_status "RUN_FAILED"
      lib.panics_add "daemon_max_recovery_attempts" <<EOF
The daemon failed and exited after too many retries. Time of failure: $(date).
EOF
      exit 1
    fi
    daemon.log_info "Recover - restarting the lifecycle in 5 seconds."
    daemon.update_status "RECOVERING"
    sleep 5
    daemon.main
  fi
}

daemon.main_setup "$@"
daemon.main
