#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

daemon_main__pid=$$
daemon_main__phase_kill_count=0
daemon_main__phase_cache="$(mktemp -d)"
daemon_main__daemon_data_dir="${HOME}/.solos/data/daemon"
daemon_main__plugins_data_dir="${HOME}/.solos/data/plugins"
daemon_main__pid_file="${daemon_main__daemon_data_dir}/pid"
daemon_main__status_file="${daemon_main__daemon_data_dir}/status"
daemon_main__kill_file="${daemon_main__daemon_data_dir}/kill"
daemon_main__log_file="${daemon_main__daemon_data_dir}/master.log"
daemon_main__collections_dir="${daemon_main__plugins_data_dir}/collections"
daemon_main__processed_file="${daemon_main__plugins_data_dir}/processed.log"
daemon_main__users_home_dir="$(lib.home_dir_path)"
daemon_main__checked_out_project="$(lib.checked_out_project)"
daemon_main__prev_pid="$(cat "${daemon_main__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon_main__report_string='Please report to https://github.com/InterBolt/solos/issues.'

daemon_main.host_path() {
  local path="${1}"
  echo "${path/\/root\//${daemon_main__users_home_dir}\/}"
}

# Load the log functions and set the custom logfile separate from the logs generated
# by the user in the foreground
. "${HOME}/.solos/src/bash/log.sh" || exit 1
if [[ ! -f ${daemon_main__log_file} ]]; then
  touch "${daemon_main__log_file}"
fi
log.use_custom_logfile "${daemon_main__log_file}"
# The --dev flag is something we need to test the daemon in the foreground for better debugging.
# Ensure that when supplied, our logs will be written to the console as well as the file.
if [[ ${1} != "--dev" ]]; then
  log.use_file_only
fi

# Consider a more elegant way to enforce log prefixes for daemon components.
daemon_main.log_info() {
  local message="(MAIN) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.info "${message}" "$@"
}
daemon_main.log_error() {
  local message="(MAIN) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.error "${message}" "$@"
}
daemon_main.log_warn() {
  local message="(MAIN) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.warn "${message}" "$@"
}

daemon_main.log_info "Daemon process started with pid: ${daemon_main__pid}"
# If the daemon is already running, we should abort the launch.
# Important: abort but do not update the status. The status file should pertain
# to the actually running daemon process, not this one.
if [[ -n ${daemon_main__prev_pid} ]] && [[ ${daemon_main__prev_pid} -ne ${daemon_main__pid} ]]; then
  if ps -p "${daemon_main__prev_pid}" >/dev/null; then
    daemon_main.log_error "Aborting launch due to existing daemon process with pid: ${daemon_main__prev_pid}"
    exit 1
  fi
fi

# Clean any old files that will interfere with the daemon's state assumptions.
if rm -f "${daemon_main__pid_file}"; then
  daemon_main.log_info "Cleared previous pid file: \"$(daemon_main.host_path "${daemon_main__pid_file}")\""
fi
if rm -f "${daemon_main__kill_file}"; then
  daemon_main.log_info "Cleared previous kill file: \"$(daemon_main.host_path "${daemon_main__kill_file}")\""
fi

# We'll use the "main" function from each script to handle the plugin lifecycles.
# Ie. collector.main, push.main, processor.main.
. "${HOME}/.solos/src/bash/container/daemon-scrub.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-phase-pull.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-phase-collector.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-phase-processor.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-phase-push.sh" || exit 1

# Validate any status changes and print the status message.
# Note: we may need more statuses to improve various failure cases
# but this is a good start.
declare -A statuses=(
  ["UP"]="The daemon is running."
  ["LAUNCHING"]="The daemon is launching."
  ["UNHANDLED_ERROR"]="An unhandled error occurred. ${daemon_main__report_string}"
  ["USER_KILLED"]="The daemon was killed by the user."
)
daemon_main.update_status() {
  local status="$1"
  if [[ -z ${statuses[${status}]} ]]; then
    echo "UNHANDLED_ERROR" >"${daemon_main__status_file}"
    daemon_main.log_error "Tried to update to an invalid status: \"${status}\""
    daemon_main.log_info "${statuses[${status}]}"
    exit 1
  fi
  echo "${status}" >"${daemon_main__status_file}"
  daemon_main.log_info "Daemon status updated to: \"${status}\" - \"${statuses[${status}]}\""
}
# Wrap the saving op for better error handling.
daemon_main.save_pid() {
  if [[ -z ${daemon_main__pid} ]]; then
    daemon_main.log_error "Can't save an empty pid to the pid file: \"$(daemon_main.host_path "${daemon_main__pid_file}")\""
    return 1
  fi
  echo "${daemon_main__pid}" >"${daemon_main__pid_file}"
}
# Will run at the end of each loop iteration to enable "clean" exits.
daemon_main.found_user_kill_request_file() {
  if [[ -f ${daemon_main__kill_file} ]]; then
    local kill_pid="$(cat "${daemon_main__kill_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ ${kill_pid} -eq ${daemon_main__pid} ]]; then
      if rm -f "${daemon_main__kill_file}"; then
        daemon_main.log_info "Removed the kill file: \"$(daemon_main.host_path "${daemon_main__kill_file}")\""
      else
        daemon_main.log_error "Failed to remove the kill file: \"$(daemon_main.host_path "${daemon_main__kill_file}")\""
        exit 1
      fi
      return 0
    fi
    if [[ -n ${kill_pid} ]]; then
      daemon_main.log_error "Something went very wrong. The targeted pid in the kill file: ${kill_pid} is not the current daemon pid: ${daemon_main__pid}."
      daemon_main.log_error "Exiting from this daemon process to prevent confusion."
      exit 1
    fi
  fi
  return 1
}
# Init anything needed before starting the daemon and prevent any particularly strange
# errors that we don't account for and can't handle gracefully.
daemon_main.start() {
  mkdir -p "${daemon_main__plugins_data_dir}"
  mkdir -p "${daemon_main__daemon_data_dir}"
  if [[ ! -f ${daemon_main__log_file} ]]; then
    touch "${daemon_main__log_file}"
    daemon_main.log_info "Created master log file: \"$(daemon_main.host_path "${daemon_main__log_file}")\""
  fi
  if [[ ! -d ${daemon_main__collections_dir} ]]; then
    mkdir -p "${daemon_main__collections_dir}"
    daemon_main.log_info "Created collections dir: \"$(daemon_main.host_path "${daemon_main__collections_dir}")\""
  fi
  if [[ ! -f ${daemon_main__processed_file} ]]; then
    touch "${daemon_main__processed_file}"
    daemon_main.log_info "Created processed file: \"$(daemon_main.host_path "${daemon_main__processed_file}")\""
  fi
  # Speculation: Given that we check for an already running Daemon at the top, I can only see this
  # happening if another daemon is started between the time the pid file is removed and here.
  # Seems like a very unlikely scenario unless a bug prevents this line from executing in a timely way.
  if [[ -f ${daemon_main__pid_file} ]]; then
    daemon_main.log_error "\"$(daemon_main.host_path "${daemon_main__pid_file}")\" already exists. This should never happen."
    return 1
  fi
  if ! daemon_main.save_pid; then
    daemon_main.log_error "Failed to save the daemon pid: \"${daemon_main__pid}\" to \"$(daemon_main.host_path "${daemon_main__pid_file}")\""
    return 1
  fi
}
daemon_main.handle_phase_kill_request() {
  local phase="$1"
  local remaining_attempts=$((10 - daemon_main__phase_kill_count))
  daemon_main.log_error "Lifecycle - kill code (151) detected from the phase: ${phase}. Will try to recover ${remaining_attempts} more times."
  if [[ ${daemon_main__phase_kill_count} -gt 9 ]]; then
    daemon_main.log_error "Lifecycle - kill code (151) detected 10 times. Exiting the daemon."
    return 151
  fi
  daemon_main__phase_kill_count=$((daemon_main__phase_kill_count + 1))
  return 0
}
daemon_main.handle_phases_succeeded() {
  daemon_main__phase_kill_count=0
  return 0
}
daemon_main.run() {
  local phase_kill_request_message="phase failed with a non-151 code (151 indicates a phase asking to kill the daemon)."
  while true; do
    local scrubbed_volume_dir="$(daemon_scrub.main)"
    local pulled_data_dir="$(mktemp -d)"
    local collections_dir="$(mktemp -d)"
    local processed_file="$(mktemp)"
    if [[ -z ${scrubbed_volume_dir} ]]; then
      daemon_main.log_error "Something went wrong with the safe copy."
      return 1
    fi
    # ------------------------------------------------------------------------------------
    #
    # PULL PHASE:
    # let plugins download anything they need before they gain access to the data.
    #
    # ------------------------------------------------------------------------------------
    if ! daemon_phase_pull.main "${pulled_data_dir}" "${daemon_main__phase_cache}"; then
      if [[ $? -eq 151 ]]; then
        daemon_main.handle_phase_kill_request "pull"
        return "$?"
      fi
      daemon_main.log_error "Lifecycle - pull ${phase_kill_request_message}"
    else
      daemon_main.log_info "Lifecycle - collector ran successfully."
    fi
    # ------------------------------------------------------------------------------------
    #
    # COLLECTOR PHASE:
    # Let plugins collect the data they need in combination with data they pulled
    # previously to generate a directory full of data.
    #
    # ------------------------------------------------------------------------------------
    if ! daemon_phase_collector.main "${scrubbed_volume_dir}" "${pulled_data_dir}" "${collections_dir}"; then
      if [[ $? -eq 151 ]]; then
        daemon_main.handle_phase_kill_request "collector"
        return "$?"
      fi
      daemon_main.log_error "Lifecycle - collector ${phase_kill_request_message}"
    else
      daemon_main.log_info "Lifecycle - collector ran successfully."
    fi
    # ------------------------------------------------------------------------------------
    #
    # PROCESSOR PHASE:
    # Allow all plugins to access the collected data. Any one plugin can access the data
    # generated by another plugin. This is key to allow plugins to work together.
    #
    # ------------------------------------------------------------------------------------
    if ! daemon_phase_processor.main "${collections_dir}" >"${processed_file}"; then
      if [[ $? -eq 151 ]]; then
        daemon_main.handle_phase_kill_request "processor"
        return "$?"
      fi
      daemon_main.log_error "Lifecycle - processor ${phase_kill_request_message}"
    else
      daemon_main.log_info "Lifecycle - processor ran successfully."
    fi
    # ------------------------------------------------------------------------------------
    #
    # PUSH PHASE:
    # Let plugins review all the processed data across all other plugins and push it
    # to a remote location or service. Ex: a plugin might include a push that pushes
    # processed data to a RAG-as-a-service backend.
    #
    # ------------------------------------------------------------------------------------
    if ! daemon_phase_push.main "${processed_file}"; then
      if [[ $? -eq 151 ]]; then
        daemon_main.handle_phase_kill_request "push"
        return "$?"
      fi
      daemon_main.log_error "Lifecycle - push ${phase_kill_request_message}"
    else
      daemon_main.log_info "Lifecycle - push ran successfully."
    fi
    daemon_main.handle_phases_succeeded
    daemon_main.log_warn "Done - all phases ran successfully. Waiting for the next cycle."
    sleep 2
    if daemon_main.found_user_kill_request_file; then
      if ! daemon_main.update_status "USER_KILLED"; then
        daemon_main.log_error "Failed to update the daemon status to USER_KILLED."
        return 1
      fi
      break
    fi
  done
  return 0
}
daemon_main.main() {
  if ! daemon_main.update_status "LAUNCHING"; then
    daemon_main.log_error "Unexpected error: failed to update the daemon status to LAUNCHING."
    daemon_main.log_error "${daemon_main__report_string}"
    exit 1
  fi
  if ! daemon_main.start; then
    daemon_main.log_error "Unexpected error: failed to start the daemon process."
    if ! daemon_main.update_status "UNHANDLED_ERROR"; then
      daemon_main.log_error "Unexpected error: failed to update the daemon status to UNHANDLED_ERROR."
    fi
    daemon_main.log_error "${daemon_main__report_string}"
    exit 1
  fi
  if ! daemon_main.update_status "UP"; then
    daemon_main.log_error "Unexpected error: failed to update the daemon status to UP."
    daemon_main.log_error "${daemon_main__report_string}"
    exit 1
  fi
  if ! daemon_main.run; then
    daemon_main.log_error "Unexpected error: daemon exited with a non-zero return code."
    if ! daemon_main.update_status "UNHANDLED_ERROR"; then
      daemon_main.log_error "Unexpected error: failed to update the daemon status to UNHANDLED_ERROR."
    fi
    daemon_main.log_error "${daemon_main__report_string}"
    exit 1
  fi

  rm -f "${daemon_main__pid_file}"
}

daemon_main.main
