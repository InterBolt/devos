#!/usr/bin/env bash

daemon__pid=$$
daemon__data_dir="${HOME}/.solos/data/daemon"
daemon__pid_file="${daemon__data_dir}/pid"
daemon__status_file="${daemon__data_dir}/status"
daemon__kill_file="${daemon__data_dir}/kill"
daemon__logfile="${daemon__data_dir}/master.log"
daemon__prev_pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon__report_string='Please report to https://github.com/InterBolt/solos/issues.'

# Load the log functions and set the custom logfile separate from the logs generated
# by the user in the foreground. And don't bother ever writing to the console since
# this is a background process and we should rely on the \`daemon\` <tail | logs> command
# for that.
. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
log.use_custom_logfile "${daemon__logfile}"
# The --dev flag is something we need to test the daemon in the foreground for better debugging.
# Ensure that when supplied, our logs will be written to the console as well as the file.
if [[ ${1} != "--dev" ]]; then
  log.use_file_only
fi

# Consider a more elegant way to enforce log prefixes for daemon components.
daemon.master_log_info() {
  local message="(MASTER) ${1} pid=\"${daemon__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon.master_log_error() {
  local message="(MASTER) ${1} pid=\"${daemon__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon.master_log_warn() {
  local message="(MASTER) ${1} pid=\"${daemon__pid}\""
  shift
  log_warn "${message}" "$@"
}
daemon.collector_log_info() {
  local message="(COLLECTOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon.collector_log_error() {
  local message="(COLLECTOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon.collector_log_warn() {
  local message="(COLLECTOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_warn "${message}" "$@"
}
daemon.loader_log_info() {
  local message="(LOADER) ${1} pid=\"${daemon__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon.loader_log_error() {
  local message="(LOADER) ${1} pid=\"${daemon__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon.loader_log_warn() {
  local message="(LOADER) ${1} pid=\"${daemon__pid}\""
  shift
  log_warn "${message}" "$@"
}
daemon.processor_log_info() {
  local message="(PROCESSOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon.processor_log_error() {
  local message="(PROCESSOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon.processor_log_warn() {
  local message="(PROCESSOR) ${1} pid=\"${daemon__pid}\""
  shift
  log_warn "${message}" "$@"
}

daemon.master_log_info "Daemon process started with pid: ${daemon__pid}"

# If the daemon is already running, we should abort the launch.
# Important: abort but do not update the status. The status file should pertain
# to the actually running daemon process, not this one.
if [[ -n ${daemon__prev_pid} ]] && [[ ${daemon__prev_pid} -ne ${daemon__pid} ]]; then
  if ps -p "${daemon__prev_pid}" >/dev/null; then
    daemon.master_log_error "Aborting launch due to existing daemon process with pid: ${daemon__prev_pid}"
    exit 1
  fi
fi

# Clean any old files that will interfere with the daemon's state assumptions.
if rm -f "${daemon__pid_file}"; then
  daemon.master_log_info "Cleared previous pid file: \"${daemon__pid_file/\/root\//~\/}\""
fi
if rm -f "${daemon__kill_file}"; then
  daemon.master_log_info "Cleared previous kill file: \"${daemon__kill_file/\/root\//~\/}\""
fi

# We'll use the "main" function from each script to handle the plugin lifecycles.
# Ie. collector.main, loader.main, processor.main.
. "${HOME}/.solos/src/container/daemon-collector.sh" || exit 1
. "${HOME}/.solos/src/container/daemon-loader.sh" || exit 1
. "${HOME}/.solos/src/container/daemon-processor.sh" || exit 1

# Validate any status changes and print the status message.
# Note: we may need more statuses to improve various failure cases
# but this is a good start.
declare -A statuses=(
  ["UP"]="The daemon is running."
  ["LAUNCHING"]="The daemon is launching."
  ["UNHANDLED_ERROR"]="An unhandled error occurred. ${daemon__report_string}"
  ["USER_KILLED"]="The daemon was killed by the user."
)
daemon.update_status() {
  local status="$1"
  if [[ -z ${statuses[${status}]} ]]; then
    echo "UNHANDLED_ERROR" >"${daemon__status_file}"
    daemon.master_log_error "Tried to update to an invalid status: \"${status}\""
    daemon.master_log_info "${statuses[${status}]}"
    exit 1
  fi
  echo "${status}" >"${daemon__status_file}"
  daemon.master_log_info "Daemon status updated to: \"${status}\" - \"${statuses[${status}]}\""
}
# Wrap the saving op for better error handling.
daemon.save_pid() {
  if [[ -z ${daemon__pid} ]]; then
    daemon.master_log_error "Can't save an empty pid to the pid file: \"${daemon__pid_file/\/root\//~\/}\""
    return 1
  fi
  echo "${daemon__pid}" >"${daemon__pid_file}"
}
# Will run at the end of each loop iteration to enable "clean" exits.
daemon.should_kill() {
  if [[ -f ${daemon__kill_file} ]]; then
    local kill_pid="$(cat "${daemon__kill_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    if [[ ${kill_pid} -eq ${daemon__pid} ]]; then
      if rm -f "${daemon__kill_file}"; then
        daemon.master_log_info "Removed the kill file: \"${daemon__kill_file/\/root\//~\/}\""
      else
        daemon.master_log_error "Failed to remove the kill file: \"${daemon__kill_file/\/root\//~\/}\""
        exit 1
      fi
      return 0
    fi
    if [[ -n ${kill_pid} ]]; then
      daemon.master_log_error "Something went very wrong. The targeted pid in the kill file: ${kill_pid} is not the current daemon pid: ${daemon__pid}."
      daemon.master_log_error "Exiting from this daemon process to prevent further damage."
      exit 1
    fi
  fi
  return 1
}
# Init anything needed before starting the daemon and prevent any particularly strange
# errors that we don't account for and can't handle gracefully.
daemon.start() {
  mkdir -p "${daemon__data_dir}"
  if [[ ! -f ${daemon__logfile} ]]; then
    touch "${daemon__logfile}"
    daemon.master_log_info "Created master log file: \"${daemon__logfile/\/root\//~\/}\""
  fi
  # Speculation: Given that we check for an already running Daemon at the top, I can only see this
  # happening if another daemon is started between the time the pid file is removed and here.
  # Seems like a very unlikely scenario unless a bug prevents this line from executing in a timely way.
  if [[ -f ${daemon__pid_file} ]]; then
    daemon.master_log_error "\"${daemon__pid_file/\/root\//~\/}\" already exists. This should never happen."
    return 1
  fi
  if ! daemon.save_pid; then
    daemon.master_log_error "Failed to save the daemon pid: \"${daemon__pid}\" to \"${daemon__pid_file/\/root\//~\/}\""
    return 1
  fi
}
daemon.run() {
  # The daemon will run until it's killed by the user.
  while true; do
    sleep 1
    if daemon.should_kill; then
      if ! daemon.update_status "USER_KILLED"; then
        daemon.master_log_error "Failed to update the daemon status to USER_KILLED."
        return 1
      fi
      break
    fi
  done
  return 0
}
daemon.main() {
  if ! daemon.update_status "LAUNCHING"; then
    daemon.master_log_error "Unexpected error: failed to update the daemon status to LAUNCHING."
    daemon.master_log_error "${daemon__report_string}"
    exit 1
  fi
  if ! daemon.start; then
    daemon.master_log_error "Unexpected error: failed to start the daemon process."
    if ! daemon.update_status "UNHANDLED_ERROR"; then
      daemon.master_log_error "Unexpected error: failed to update the daemon status to UNHANDLED_ERROR."
    fi
    daemon.master_log_error "${daemon__report_string}"
    exit 1
  fi
  if ! daemon.update_status "UP"; then
    daemon.master_log_error "Unexpected error: failed to update the daemon status to UP."
    daemon.master_log_error "${daemon__report_string}"
    exit 1
  fi
  if ! daemon.run; then
    daemon.master_log_error "Unexpected error: daemon exited with a non-zero return code."
    if ! daemon.update_status "UNHANDLED_ERROR"; then
      daemon.master_log_error "Unexpected error: failed to update the daemon status to UNHANDLED_ERROR."
    fi
    daemon.master_log_error "${daemon__report_string}"
    exit 1
  fi

  rm -f "${daemon__pid_file}"
}

daemon.main
