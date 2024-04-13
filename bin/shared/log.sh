#!/usr/bin/env bash
# shellcheck disable=SC2145
# shellcheck disable=SC2124

# shellcheck source=../pkg/gum.sh
source "pkg/gum.sh"
# shellcheck source=static.sh
source "shared/static.sh"

LIB_BARE_LOG=false
LIB_FILESIZE=0
LIB_DIR="$(dirname "${vSTATIC_LOG_FILEPATH}")"

mkdir -p "${LIB_DIR}"

LIB_FILESIZE="$(du -k "${vSTATIC_LOG_FILEPATH}" | cut -f 1)"
if [[ "${LIB_FILESIZE}" -gt 1000 ]]; then
  LIB_BARE_LOG=true
  log.warn "LOG FILE IS GROWING LARGE: $((LIB_FILESIZE / 1000))MB"
  log.info "${vSTATIC_LOG_FILEPATH}"
  if command -v pbcopy &>/dev/null; then
    pbcopy <"${vSTATIC_LOG_FILEPATH}"
    log.info "log file path copied to clipboard"
  fi
fi
# -----------------------------------------------------------------------------
#
# HELPER FUNCTIONS
#
log._get_filesize() {
  if [[ -f "${1}" ]]; then
    du -k "${1}" | cut -f 1
  else
    echo 0
  fi
}
log._get_level_color() {
  local level="${1}"
  case "${level}" in
  "info")
    echo "#3B78FF"
    ;;
  "debug")
    echo "#A0A"
    ;;
  "error")
    echo "#F02"
    ;;
  "fatal")
    echo "#F02"
    ;;
  "warn")
    echo "#FA0"
    ;;
  *)
    echo "#FFF"
    ;;
  esac
}
log._base() {
  local foreground="${vENTRY_FOREGROUND:-true}"
  local debug=${DEBUG:-false}
  local date_format='+%F %T'
  local formatted_date="$(date "${date_format}")"
  local level="${1}"
  shift
  local source="${1}"
  shift
  local msg="${1}"
  shift
  local args=()
  local source_args=(source "[${source}]")
  if [[ "${source}" == "NULL"* ]]; then
    source_args=()
  fi
  #
  # `bare` logs don't include lots of info and don't log to a file.
  #
  if [[ $LIB_BARE_LOG = true ]]; then
    args=(--level "${level}" "${msg}")
  else
    args=(--time "kitchen" --structured --level "${level}" "${msg}" date "${formatted_date}")
    pkg.gum log --level.foreground "$(log._get_level_color "${level}")" --file "${vSTATIC_LOG_FILEPATH}" "${args[@]}" "${source_args[@]}"
  fi
  if [[ $level = "fatal" ]] || [[ $debug = true ]] || [[ $debug -eq 1 ]] || [[ $foreground = true ]]; then
    pkg.gum log --level.foreground "$(log._get_level_color "${level}")" "${args[@]}" "${source_args[@]}"
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
log.fatal() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "fatal" "$filename:$linenumber" "$@"
}
log.warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  filename="$(basename "$filename")"
  log._base "warn" "$filename:$linenumber" "$@"
}
log.use_minimal() {
  LIB_BARE_LOG=true
}
log.use_full() {
  LIB_BARE_LOG=true
}
