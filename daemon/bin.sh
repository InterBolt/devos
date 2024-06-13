#!/usr/bin/env bash

bin__pid=$$
bin__remaining_retries=5
bin__daemon_data_dir="${HOME}/.solos/data/daemon"
bin__pid_file="${bin__daemon_data_dir}/pid"
bin__status_file="${bin__daemon_data_dir}/status"
bin__request_file="${bin__daemon_data_dir}/request"
bin__log_file="${bin__daemon_data_dir}/master.log"
bin__prev_pid="$(cat "${bin__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"

trap 'rm -f "'"${bin__pid_file}"'"' EXIT

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/shared/log.sh" || exit 1
. "${HOME}/.solos/src/daemon/shared.sh" || exit 1
. "${HOME}/.solos/src/daemon/task-scrub.sh" || exit 1
. "${HOME}/.solos/src/daemon/plugin-phases.sh" || exit 1

declare -A statuses=(
  ["UP"]="The daemon is running."
  ["RECOVERING"]="The daemon is recovering from a nonfatal error."
  ["RUN_FAILED"]="The daemon plugin lifecycle failed in an unrecoverable way and stopped running to limit damage."
  ["START_FAILED"]="The daemon failed to start up."
  ["LAUNCHING"]="The daemon is starting up."
  ["KILLED"]="The user killed the daemon process."
)
bin.update_status() {
  local status="$1"
  if [[ -z ${statuses[${status}]} ]]; then
    shared.log_error "Unexpected error - tried to update to an invalid status: \"${status}\""
    exit 1
  fi
  echo "${status}" >"${bin__status_file}"
  shared.log_info "Status - updated to: \"${status}\" - \"${statuses[${status}]}\""
}
bin.extract_request() {
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
bin.handle_request() {
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
bin.update_configs() {
  local merged_configure_dir="${1}"
  local solos_plugin_names=($(shared.get_solos_plugin_names))
  local user_plugin_names=($(shared.get_user_plugin_names))
  local precheck_plugin_names=($(shared.get_precheck_plugin_names))
  local plugin_names=("${precheck_plugin_names[@]}" "${solos_plugin_names[@]}" "${user_plugin_names[@]}")
  local plugin_paths=($(shared.plugin_names_to_paths "${plugin_names[@]}"))
  for plugin_path in "${plugin_paths[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    local plugin_dir="$(dirname "${plugin_path}")"
    local config_path="${plugin_dir}/solos.json"
    local updated_config_path="${merged_configure_dir}/${plugin_name}.json"
    if [[ -f ${updated_config_path} ]]; then
      rm -f "${config_path}"
      cp "${updated_config_path}" "${config_path}"
      shared.log_info "Config - updated the config at ${config_path}."
    fi
  done
}
bin.dump() {
  local phase="${1}"
  local log_file="${2}"
  local aggregated_stdout_file="${3}"
  local aggregated_stderr_file="${4}"
  echo "[${phase}:stdout]" >>"${log_file}"
  while IFS= read -r line; do
    echo "${line}" >>"${log_file}"
  done <"${aggregated_stdout_file}"
  echo "[${phase}:stderr]" >>"${log_file}"
  while IFS= read -r line; do
    echo "${line}" >>"${log_file}"
  done <"${aggregated_stderr_file}"
}
bin.run_plugins() {
  local plugins=("${@}")

  # Prep the archive directory.
  local nano_seconds="$(date +%s%N)"
  local next_archive_dir="${HOME}/.solos/data/daemon/archives/${nano_seconds}"
  mkdir -p "${next_archive_dir}"
  local archive_log_file="${next_archive_dir}/dump.log"
  touch "${archive_log_file}"

  local scrubbed_dir="$(daemon_task_scrub.main)"
  if [[ -z ${scrubbed_dir} ]]; then
    shared.log_error "Unexpected error - failed to scrub the mounted volume."
    return 1
  fi
  cp -r "${scrubbed_dir}" "${next_archive_dir}/scrubbed"
  shared.log_info "Progress - archived the scrubbed data at \"$(shared.host_path "${next_archive_dir}/scrubbed")\""
  # ------------------------------------------------------------------------------------
  #
  # CONFIGURE PHASE:
  # Allow plugins to create a default config if none was provided, or modify the existing
  # one if it detects abnormalities.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! plugin_phases.configure "${plugins[@]}" >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    shared.log_error "Nonfatal - the configure phase failed with return code ${return_code}."
  else
    shared.log_info "Progress - the configure phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_configure_dir="$(lib.line_to_args "${result}" "2")"
  bin.dump "configure" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  bin.update_configs "${merged_configure_dir}"
  shared.log_info "Progress - updated configs based on the configure phase."
  cp -r "${merged_configure_dir}" "${next_archive_dir}/configure"
  shared.log_info "Progress - archived the configure data at \"$(shared.host_path "${next_archive_dir}/configure")\""
  # ------------------------------------------------------------------------------------
  #
  # DOWNLOAD PHASE:
  # let plugins download anything they need before they gain access to the data.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! plugin_phases.download \
    "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    shared.log_error "Nonfatal - the download phase failed with return code ${return_code}."
  else
    shared.log_info "Progress - the download phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_download_dir="$(lib.line_to_args "${result}" "2")"
  local plugin_download_dirs=($(lib.line_to_args "${result}" "3"))
  bin.dump "download" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  cp -r "${merged_download_dir}" "${next_archive_dir}/download"
  shared.log_info "Progress - archived the download data at \"$(shared.host_path "${next_archive_dir}/download")\""
  # ------------------------------------------------------------------------------------
  #
  # PROCESSOR PHASE:
  # Allow all plugins to access the collected data. Any one plugin can access the data
  # generated by another plugin. This is key to allow plugins to work together.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! plugin_phases.process \
    "${scrubbed_dir}" "${merged_download_dir}" "${plugin_download_dirs[*]}" \
    "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    shared.log_error "Nonfatal - the process phase failed with return code ${return_code}."
  else
    shared.log_info "Progress - the process phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_processed_dir="$(lib.line_to_args "${result}" "2")"
  local plugin_processed_files=($(lib.line_to_args "${result}" "3"))
  bin.dump "process" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  cp -r "${merged_processed_dir}" "${next_archive_dir}/processed"
  shared.log_info "Progress - archived the processed data at \"$(shared.host_path "${next_archive_dir}/processed")\""
  # ------------------------------------------------------------------------------------
  #
  # CHUNK PHASE:
  # Converts processed data into pure text chunks.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! plugin_phases.chunk \
    "${merged_processed_dir}" "${plugin_processed_files[*]}" \
    "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    shared.log_error "Nonfatal - the chunk phase failed with return code ${return_code}."
  else
    shared.log_info "Progress - the chunk phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_chunks_dir="$(lib.line_to_args "${result}" "2")"
  local plugin_chunk_files=($(lib.line_to_args "${result}" "3"))
  bin.dump "chunk" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  cp -r "${merged_chunks_dir}" "${next_archive_dir}/chunks"
  shared.log_info "Progress - archived the chunk data at \"$(shared.host_path "${next_archive_dir}/chunks")\""
  # ------------------------------------------------------------------------------------
  #
  # PUBLISH PHASE:
  # Any last second processing before the chunks are sent to a remote server,
  # third party LLM, local llm, vector db, etc. Ex: might want to use a low cost
  # LLM to generate keywords for chunks.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  if ! plugin_phases.publish \
    "${merged_chunks_dir}" "${plugin_chunk_files[*]}" \
    "${plugins[@]}" \
    >"${tmp_stdout}"; then
    local return_code="$?"
    if [[ ${return_code} -eq 151 ]]; then
      return "${return_code}"
    fi
    shared.log_error "Nonfatal - the publish phase failed with return code ${return_code}."
  else
    shared.log_info "Progress - the publish phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  bin.dump "publish" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  shared.log_info "Progress - archival complete at \"$(shared.host_path "${next_archive_dir}")\""
}
bin.run() {
  local is_precheck=true
  while true; do
    plugins=()
    if [[ ${is_precheck} = true ]]; then
      local precheck_plugin_names="$(shared.get_precheck_plugin_names)"
      plugins=($(shared.plugin_names_to_paths "${precheck_plugin_names[@]}"))
    else
      local solos_plugin_names="$(shared.get_solos_plugin_names)"
      local user_plugin_names="$(shared.get_user_plugin_names)"
      local solos_plugins=($(shared.plugin_names_to_paths "${solos_plugin_names[@]}"))
      local user_plugins=($(shared.plugin_names_to_paths "${user_plugin_names[@]}"))
      plugins=("${solos_plugins[@]}" "${user_plugins[@]}")
    fi
    [[ ${is_precheck} = true ]] && is_precheck=false || is_precheck=true
    if [[ ${#plugins[@]} -eq 0 ]]; then
      shared.log_warn "Halting - no plugins were found. Waiting 10 seconds before the next run."
      sleep 10
      continue
    fi
    shared.log_info "Progress - starting a new cycle."
    bin.run_plugins "${plugins[@]}"
    shared.log_info "Progress - archived phase results at \"$(shared.host_path "${archive_dir}")\""
    shared.log_warn "Done - waiting for the next cycle."
    bin__remaining_retries=5
    sleep 2
    local request="$(bin.extract_request "${bin__request_file}")"
    if [[ -n ${request} ]]; then
      shared.log_info "Request - ${request} was dispatched to the bin."
      bin.handle_request "${request}"
    fi
  done
  return 0
}
bin.main_setup() {
  if [[ ! -f ${bin__log_file} ]]; then
    touch "${bin__log_file}"
  fi
  log.use_custom_logfile "${bin__log_file}"
  # The --dev flag is something we need to test the daemon in the foreground for better debugging.
  # Ensure that when supplied, our logs will be written to the console as well as the file.
  if [[ ${1} != "--dev" ]]; then
    log.use_file_only
  fi
  # Clean any old files that will interfere with the daemon's state assumptions.
  if rm -f "${bin__pid_file}"; then
    shared.log_info "Setup - cleared previous pid file: \"$(shared.host_path "${bin__pid_file}")\""
  fi
  if rm -f "${bin__request_file}"; then
    shared.log_info "Setup - cleared previous request file: \"$(shared.host_path "${bin__request_file}")\""
  fi
  # If the daemon is already running, we should abort the launch.
  # Important: abort but do not update the status. The status file should pertain
  # to the actually running daemon process, not this one.
  if [[ -n ${bin__prev_pid} ]] && [[ ${bin__prev_pid} -ne ${bin__pid} ]]; then
    if ps -p "${bin__prev_pid}" >/dev/null; then
      shared.log_error "Unexpected error - aborting launch due to existing daemon process with pid: ${bin__prev_pid}"
      exit 1
    fi
  fi
}
bin.main() {
  bin.update_status "LAUNCHING"
  if [[ -f ${bin__pid_file} ]]; then
    shared.log_error "Unexpected error - \"$(shared.host_path "${bin__pid_file}")\" already exists. This should never happen."
    bin.update_status "START_FAILED"
    lib.panics_add "daemon_pid_file_already_exists" <<EOF
The daemon failed to start up because the pid file already exists. Time of failure: $(date).
EOF
    return 1
  fi
  if [[ -z ${bin__pid} ]]; then
    shared.log_error "Unexpected error - can't save an empty pid to the pid file: \"$(shared.host_path "${bin__pid_file}")\""
    bin.update_status "START_FAILED"
    lib.panics_add "daemon_empty_pid" <<EOF
The daemon failed to start up because it could not determine it's PID. Time of failure: $(date).
EOF 
    return 1
  fi
  echo "${bin__pid}" >"${bin__pid_file}"
  bin.update_status "UP"
  bin.run
  local return_code=$?
  if [[ ${return_code} -eq 151 ]]; then
    shared.log_error "Fatal - killing the daemon due to a custom error code: 151."
    bin.update_status "RUN_FAILED"
    lib.panics_add "daemon_plugins_failed" <<EOF
The daemon failed and exited as a result of a SOLOS_PANIC signal from a running plugin. \
Time of failure: $(date).
EOF
    exit 151
  else
    bin__remaining_retries=$((bin__remaining_retries - 1))
    if [[ ${bin__remaining_retries} -eq 0 ]]; then
      shared.log_error "Fatal - killing the daemon due to too many failures."
      bin.update_status "RUN_FAILED"
      lib.panics_add "daemon_max_recovery_attempts" <<EOF
The daemon failed and exited after too many retries. Time of failure: $(date).
EOF
      exit 1
    fi
    shared.log_info "Recover - restarting the lifecycle in 5 seconds."
    bin.update_status "RECOVERING"
    sleep 5
    bin.main
  fi
}

# bin.main_setup "$@"
# bin.main
