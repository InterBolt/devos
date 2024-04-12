#!/usr/bin/env bash
# shellcheck disable=SC2145
# shellcheck disable=SC2124

# shellcheck source=../pkg/gum.sh
source "pkg/gum.sh"

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
# -----------------------------------------------------------------------------
#
# HELPER FUNCTIONS
#
log._get_filesize() {
  if [ -f "${1}" ]; then
    du -k "${1}" | cut -f 1
  else
    echo 0
  fi
}
log._get_active_logfile() {
  local dir="$LIB_DIR"
  if [ -z "${dir}" ]; then
    echo ""
    return
  fi
  local curr_logfile
  local curr_idx=0

  for logfile in "$dir"/*; do
    logfile_idx=$(echo "$logfile" | grep -o -E '[0-9]+')
    if [ $((logfile_idx)) -gt $((curr_idx)) ]; then
      curr_idx=$logfile_idx
    fi
  done
  curr_logfile="${dir}/${LIB_LOG_PREFIX}${curr_idx}.log"
  should_rotate=0
  size="$(log._get_filesize "${curr_logfile}")"
  if [ $((size)) -gt $((LIB_LOG_ROLLSIZE_KBS)) ]; then
    should_rotate=1
  fi
  if [ $should_rotate -eq 1 ]; then
    echo "${dir}/${LIB_LOG_PREFIX}$((curr_idx + 1)).log"
  else
    echo "${dir}/${LIB_LOG_PREFIX}${curr_idx}.log"
  fi
}
log._base() {
  local active_logfile=""
  if [ "${LIB_READY_LOG}" == "false" ]; then
    active_logfile=""
  else
    active_logfile="$(log._get_active_logfile)"
  fi
  local date_format='+%F %T'
  local formatted_date="$(date "${date_format}")"
  local level="${1}"
  shift
  local source="${1}"
  shift
  local msg="${1}"
  shift
  local line="${@}"
  if [ -z "${active_logfile}" ]; then
    pkg.gum log --time "kitchen" --structured --level "${level}" "${msg}" source "${source}" date "${formatted_date}" "${line}"
  else
    pkg.gum log --time "kitchen" --structured --level "${level}" "${msg}" source "${source}" date "${formatted_date}" "${line}" >>"${active_logfile}"
  fi
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
  log._base "info" "$filename:$linenumber" "$@"
}
log.debug() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "debug" "$filename:$linenumber" "$@"
}
log.error() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "error" "$filename:$linenumber" "$@"
}
log.warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "warn" "$filename:$linenumber" "$@"
}
log.ready() {
  LIB_LOG_PREFIX="$1."
  LIB_DIR="$2"
  if [ -z "${LIB_LOG_PREFIX}" ]; then
    log.error "log prefix not set at log.ready"
    exit 1
  fi
  if [ -z "${LIB_DIR}" ]; then
    log.debug "did not specify a log dir. will not save logs to disk."
  else
    mkdir -p "${LIB_DIR}"
  fi
  LIB_READY_LOG=true
  log.debug "shared.log - setting log prefix: ${LIB_LOG_PREFIX}"
  log.debug "shared.log - ready"
}
