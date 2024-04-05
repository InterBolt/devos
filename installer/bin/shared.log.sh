#!/usr/bin/env bash
# shellcheck disable=SC2155
# shellcheck disable=SC2145
# shellcheck disable=SC2124

# shellcheck source=devos.static
source "devos.static"

# -----------------------------------------------------------------------------
#
# FILE NOTES:
#
# This file is a logging library that can be sourced into a bash script.
# Unlike bin/lib.* scripts, this script is prefixed bin/shared.* to indicate
# that is something we might want to use in our aliased dev env scripts.
# The code was adapted from this library: https://github.com/Zordrak/bashlog

#
# The level variables below are doing the work of
# what a map might do if mapping the level number and color to
# the name of the level.
#
# -----------------------------------------------------------------------------
#
# SCRIPT VARS
#
# Script-specific variables that come from the invocation of log.ready.
#
#
# Tracks whether or not log.ready was called.
#
LIB_READY_LOG=false
#
# results in logfile - $LIB_LOG_PREFIX.<rollindex>.json
#
LIB_LOG_PREFIX=""
#
# roughly 10 megabytes per log file.
#
LIB_LOG_ROLLSIZE_KBS=10000
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
  du -s "$1" | cut -f 1
}
log._get_active_logfile() {
  mkdir -p "$vSTATIC_MY_ROOT/$vSTATIC_LOGS_DIRNAME"

  local curr_logfile
  local curr_idx=0
  local dir="$vSTATIC_MY_ROOT/$vSTATIC_LOGS_DIRNAME"

  for logfile in "$dir"/*; do
    logfile_idx=$(echo "$logfile" | grep -o -E '[0-9]+')
    if [ $((logfile_idx)) -gt $((curr_idx)) ]; then
      curr_idx=$logfile_idx
    fi
  done
  curr_logfile="$dir/$LIB_LOG_PREFIX$curr_idx.json"
  should_rotate=0
  size="$(log._get_filesize "$curr_logfile")"
  if [ $((size)) -gt $((LIB_LOG_ROLLSIZE_KBS)) ]; then
    should_rotate=1
  fi
  if [ $should_rotate -eq 1 ]; then
    echo "$dir/$LIB_LOG_PREFIX$((curr_idx + 1)).json"
  else
    echo "$dir/$LIB_LOG_PREFIX$curr_idx.json"
  fi
}
#
# Main logging logic.
#
log._base() {
  if [ -z "${LIB_READY_LOG}" ]; then
    echo "must run log.ready before logging" >&2
    exit 1
  fi
  local date_format='+%F %T'
  local date="$(date "${date_format}")"
  local date_s="$(date "+%s")"
  local json_path="$(log._get_active_logfile)"
  local level="${1}"
  local debug_level="${vDEBUG_LEVEL:-0}"
  shift
  local source="${1}"
  shift
  local line="${@}"
  local severity_name="${level}_LOG_SEVERITY"
  local severity="${!severity_name}"
  if [ "${debug_level}" -gt 0 ] || [ "${severity}" -lt 7 ]; then
    local json_line="$(printf '{"timestamp":"%s","level":"%s", "source": "%s", "message":"%s"}' "${date_s}" "${level}" "$source" "${line}")"
    echo -e "${json_line}" >>"${json_path}" ||
      log._exception "echo -e \"${json_line}\" >> \"${json_path}\""
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
  LIB_LOG_PREFIX="${1:-""}"
  if [ -n "${LIB_LOG_PREFIX}" ]; then
    LIB_LOG_PREFIX="${LIB_LOG_PREFIX}."
  fi
  LIB_READY_LOG=true
  vDEBUG_LEVEL="${2:-0}"
  log.debug "shared.log - setting log prefix: ${LIB_LOG_PREFIX}"
  log.debug "shared.log - setting debug level: ${vDEBUG_LEVEL:-0}"
  log.debug "shared.log - ready"
}
