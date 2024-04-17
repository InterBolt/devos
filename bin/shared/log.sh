#!/usr/bin/env bash
# shellcheck disable=SC2145
# shellcheck disable=SC2124

# shellcheck source=../pkg/gum.sh
source "pkg/gum.sh"

# shellcheck source=static.sh
source "shared/static.sh"

vLIB_LOG_BARE_LOG=false
vLIB_LOG_FILESIZE=0
vLIB_LOG_DIR="$(dirname "${vSTATIC_LOG_FILEPATH}")"

mkdir -p "${vLIB_LOG_DIR}"

vLIB_LOG_FILESIZE="$(du -k "${vSTATIC_LOG_FILEPATH}" | cut -f 1)"
if [[ ${vLIB_LOG_FILESIZE} -gt 1000 ]]; then
  vLIB_LOG_BARE_LOG=true
  log.warn "LOG FILE IS GROWING LARGE: $((vLIB_LOG_FILESIZE / 1000))MB"
  log.info "${vSTATIC_LOG_FILEPATH}"
  if command -v pbcopy &>/dev/null; then
    pbcopy <"${vSTATIC_LOG_FILEPATH}"
    log.info "log file path copied to clipboard"
  fi
fi
log._get_filesize() {
  if [[ -f ${1} ]]; then
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
  mkdir -p "$(dirname "${vSTATIC_LOG_FILEPATH}")"
  if [[ ! -f ${vSTATIC_LOG_FILEPATH} ]]; then
    touch "${vSTATIC_LOG_FILEPATH}"
  fi

  local foreground="${vSOLOS_USE_FOREGROUND_LOGS:-true}"
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

  # The thinking is that if the source is NULL, we're almost certainly running
  # the script via piping a curled script to bash. We can limit debugging info
  # in the log line because their's likely no file to reference on the local
  # machine.
  local date_args=(date "${formatted_date}")
  local source_args=(source "[${source}]")
  if [[ ${source} == "NULL"* ]]; then
    source_args=()
    date_args=()
  fi

  # `bare` logs don't include lots of info and don't log to a file.
  if [[ $vLIB_LOG_BARE_LOG = true ]]; then
    args=(--level "${level}" "${msg}")
  else
    args=(--time "kitchen" --structured --level "${level}" "${msg}")
    pkg.gum log --level.foreground "$(log._get_level_color "${level}")" --file "${vSTATIC_LOG_FILEPATH}" "${args[@]}" "${source_args[@]}" "${date_args[@]}"
  fi
  if [[ $level = "fatal" ]] || [[ $debug = true ]] || [[ $debug -eq 1 ]] || [[ $foreground = true ]]; then
    pkg.gum log --level.foreground "$(log._get_level_color "${level}")" "${args[@]}" "${source_args[@]}" "${date_args[@]}"
  fi
}
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
  vLIB_LOG_BARE_LOG=true
}
log.use_full() {
  vLIB_LOG_BARE_LOG=true
}
