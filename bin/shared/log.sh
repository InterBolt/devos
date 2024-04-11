#!/usr/bin/env bash
# shellcheck disable=SC2145
# shellcheck disable=SC2124

DEBUG_LEVEL=${DEBUG_LEVEL:-0}

LIB_DIR=""
LIB_READY_LOG=false
#
# results in logfile - $LIB_LOG_PREFIX.<rollindex>.json
#
LIB_LOG_PREFIX=""
#
# roughly 1 megabytes per log file.
#
LIB_LOG_ROLLSIZE_KBS=1000
#
# Level variables.
#
# - DEBUG
#
# shellcheck disable=SC2034
DEBUG_LOG_SEVERITY=7
# shellcheck disable=SC2034
DEBUG_LOG_COLOR='\033[34m'
#
# - INFO
#
# shellcheck disable=SC2034
INFO_LOG_SEVERITY=6
# shellcheck disable=SC2034
INFO_LOG_COLOR='\033[32m'
#
# - NOTICE
#
# shellcheck disable=SC2034
NOTICE_LOG_SEVERITY=5
# shellcheck disable=SC2034
NOTICE_LOG_COLOR=''
#
# - WARN
#
# shellcheck disable=SC2034
WARN_LOG_SEVERITY=4
# shellcheck disable=SC2034
WARN_LOG_COLOR='\033[33m'
#
# - ERROR
#
# shellcheck disable=SC2034
ERROR_LOG_SEVERITY=3
# shellcheck disable=SC2034
ERROR_LOG_COLOR='\033[31m'
#
# - CRIT
#
# shellcheck disable=SC2034
CRIT_LOG_SEVERITY=2
# shellcheck disable=SC2034
CRIT_LOG_COLOR=''
#
# - ALERT
#
# shellcheck disable=SC2034
ALERT_LOG_SEVERITY=1
# shellcheck disable=SC2034
ALERT_LOG_COLOR=''
#
# - EMERG
#
# shellcheck disable=SC2034
EMERG_LOG_SEVERITY=0
# shellcheck disable=SC2034
EMERG_LOG_COLOR=''
#
# - DEFAULT
#
# shellcheck disable=SC2034
DEFAULT_LOG_COLOR='\033[0m'

# -----------------------------------------------------------------------------
#
# HELPER FUNCTIONS
#
log._exception() {
  (
    log._base 'ERROR' "-" "Logging Exception: ${@}"
  )
}
log._get_filesize() {
  if [ -f "${1}" ]; then
    du -k "${1}" | cut -f 1
  else
    echo 0
  fi
}
log._get_active_logfile() {
  local dir="$LIB_DIR"
  local curr_logfile
  local curr_idx=0

  for logfile in "$dir"/*; do
    logfile_idx=$(echo "$logfile" | grep -o -E '[0-9]+')
    if [ $((logfile_idx)) -gt $((curr_idx)) ]; then
      curr_idx=$logfile_idx
    fi
  done
  curr_logfile="${dir}/${LIB_LOG_PREFIX}${curr_idx}.json"
  should_rotate=0
  size="$(log._get_filesize "${curr_logfile}")"
  if [ $((size)) -gt $((LIB_LOG_ROLLSIZE_KBS)) ]; then
    should_rotate=1
  fi
  if [ $should_rotate -eq 1 ]; then
    echo "${dir}/${LIB_LOG_PREFIX}$((curr_idx + 1)).json"
  else
    echo "${dir}/${LIB_LOG_PREFIX}${curr_idx}.json"
  fi
}
#
# Main logging logic.
#
log._base() {
  local json_path=""
  if [ "${LIB_READY_LOG}" == "false" ]; then
    json_path=""
  else
    json_path="$(log._get_active_logfile)"
  fi
  local date_format='+%F %T'
  local date="$(date "${date_format}")"
  local date_s="$(date "+%s")"
  local level="${1}"
  local debug_level="${DEBUG_LEVEL:-0}"
  shift
  local source="${1}"
  shift
  local line="${@}"
  local severity_name="${level}_LOG_SEVERITY"
  local severity="${!severity_name}"
  #
  # By only writing to a file when the json_path was set,
  # we ensure the log functions can be used without calling log.ready.
  #
  if [ -n "${json_path}" ]; then
    if [ "${debug_level}" -gt 0 ] || [ "${severity}" -lt 7 ]; then
      local json_line="$(printf '{"timestamp":"%s","level":"%s", "source": "%s", "message":"%s"}' "${date_s}" "${level}" "$source" "${line}")"
      echo -e "${json_line}" >>"${json_path}" ||
        log._exception "echo -e \"${json_line}\" >> \"${json_path}\""
    fi
  fi
  local color_name="${level}_LOG_COLOR"
  local norm="${DEFAULT_COLOR}"
  local color="${!color_name}"
  local std_line="[${source}]: ${date} ${color}[${level}]${DEFAULT_LOG_COLOR} ${line}${norm}"
  case "${level}" in
  'INFO' | 'WARN')
    echo -e "${std_line}"
    ;;
  'DEBUG')
    if [ "${debug_level}" -gt 0 ]; then
      echo -e "${std_line}"
    fi
    ;;
  'ERROR')
    echo -e "${std_line}" >&2
    if [ "${debug_level}" -gt 0 ]; then
      echo -e "Here's a shell to debug with. 'exit 0' to continue. Other exit codes will abort - parent shell will terminate."
      bash || exit "${?}"
    fi
    ;;
  *)
    log._base 'ERROR' "-" "Undefined log level trying to log: ${@}"
    ;;
  esac
}
# -----------------------------------------------------------------------------
#
# PUBLIC FUNCTIONS
#
# log.ready and log.<level> are the public functions.
# log.ready must be called before any other log functions to ensure
# the variables are set correctly. log.<level> will output in format:
# "[${source}]: ${date} ${color}[${upper}]${DEFAULT_COLOR} ${line}${norm}"
#
# note: log.ready is similar to a constructor for the log library.
#
log.info() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "INFO" "$filename:$linenumber" "$@"
}
log.debug() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "DEBUG" "$filename:$linenumber" "$@"
}
log.error() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "ERROR" "$filename:$linenumber" "$@"
}
log.warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "WARN" "$filename:$linenumber" "$@"
}
log.ready() {
  LIB_LOG_PREFIX="$1."
  LIB_DIR="$2"
  if [ -z "${LIB_LOG_PREFIX}" ]; then
    log.error "log prefix not set at log.ready"
    exit 1
  fi
  if [ -z "${LIB_DIR}" ]; then
    log.error "log directory not set at log.ready"
    exit 1
  fi
  LIB_READY_LOG=true
  mkdir -p "${LIB_DIR}"
  log.debug "shared.log - setting log prefix: ${LIB_LOG_PREFIX}"
  log.debug "shared.log - setting debug level: ${DEBUG_LEVEL:-0}"
  log.debug "shared.log - ready"
}
