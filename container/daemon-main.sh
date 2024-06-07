#!/usr/bin/env bash

daemon_main__pid=$$
daemon_main__data_dir="${HOME}/.solos/data/daemon"
daemon_main__pid_file="${daemon_main__data_dir}/pid"
daemon_main__status_file="${daemon_main__data_dir}/status"
daemon_main__kill_file="${daemon_main__data_dir}/kill"
daemon_main__log_file="${daemon_main__data_dir}/master.log"
daemon_main__collections_dir="${daemon_main__data_dir}/collections"
daemon_main__processed_file="${daemon_main__data_dir}/processed.log"
daemon_main__users_home_dir="$(cat "${HOME}/.solos/data/store/users_home_dir" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon_main__checked_out_project="$(cat "${HOME}/.solos/data/store/checked_out_project" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon_main__prev_pid="$(cat "${daemon_main__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon_main__report_string='Please report to https://github.com/InterBolt/solos/issues.'

daemon_main.host_path() {
  local path="${1}"
  echo "${path/\/root\//${daemon_main__users_home_dir}\/}"
}

# Load the log functions and set the custom logfile separate from the logs generated
# by the user in the foreground
. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
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
  log_info "${message}" "$@"
}
daemon_main.log_error() {
  local message="(MAIN) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_main.log_warn() {
  local message="(MAIN) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_warn "${message}" "$@"
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
# Ie. collector.main, loader.main, processor.main.
. "${HOME}/.solos/src/container/daemon-scrub.sh" || exit 1
. "${HOME}/.solos/src/container/daemon-collector.sh" || exit 1
. "${HOME}/.solos/src/container/daemon-loader.sh" || exit 1
. "${HOME}/.solos/src/container/daemon-processor.sh" || exit 1

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
daemon_main.should_kill() {
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
  mkdir -p "${daemon_main__data_dir}"
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
daemon_main.run() {
  # Individual lifecycles can fail, but the daemon should keep running.
  # It should only quit if the user explicitly kills it. Plugin authors are
  # responsible for ensuring that their plugins can fail repeatedly without
  # causing any weird side effects.
  while true; do
    local scrubbed_copy="$(daemon_scrub.main)"
    local collections_dir="$(mktemp -d)"
    local processed_file="$(mktemp)"
    if [[ -z ${scrubbed_copy} ]]; then
      daemon_main.log_error "Something went wrong with the safe copy."
      return 1
    fi
    if ! daemon_collector.main "${scrubbed_copy}" "${collections_dir}"; then
      daemon_main.log_error "Something went wrong with the collector."
    else
      daemon_main.log_info "Lifecycle - collector ran successfully."
    fi
    if ! daemon_processor.main "${collections_dir}" >"${processed_file}"; then
      daemon_main.log_error "Something went wrong with the processor."
    else
      daemon_main.log_info "Lifecycle - processor ran successfully."
    fi
    if ! daemon_loader.main "${processed_file}"; then
      daemon_main.log_error "Something went wrong with the loader."
    else
      daemon_main.log_info "Lifecycle - loader ran successfully."
    fi
    daemon_main.log_warn "Sleeping - 20 seconds before the next plugin cycle."
    sleep 20
    if daemon_main.should_kill; then
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
