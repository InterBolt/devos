#!/usr/bin/env bash
# shellcheck disable=SC2145
# shellcheck disable=SC2124

# shellcheck source=static.sh
source "shared/static.sh"

vSELF_LOG_BARE_LOG=false
vSELF_LOG_FILESIZE=0

mkdir -p "${vSTATIC_LOGS_DIR}"

vSELF_LOG_FILESIZE="$(du -k "${vSTATIC_LOG_FILEPATH}/logs.txt" | cut -f 1 || echo "")"
if [[ ${vSELF_LOG_FILESIZE} -gt 5000 ]]; then
  vSELF_LOG_BARE_LOG=true
  log.warn "LOG FILE IS GROWING LARGE: ${vSELF_LOG_FILESIZE}Kb"
  log.info "${vSTATIC_LOG_FILEPATH}/logs.txt"
fi

log._to_host_filename() {
  local filename="${1}"
  local host="$(cat "${vSTATIC_SOLOS_ROOT}/config/host")"
  echo "${filename/${HOME}/${host}}"
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
  if [[ ! -f ${vSTATIC_LOG_FILEPATH}/logs.txt ]]; then
    if ! touch "${vSTATIC_LOG_FILEPATH}/logs.txt" &>/dev/null; then
      echo "Failed to create log file: ${vSTATIC_LOG_FILEPATH}/logs.txt"
      exit 1
    fi
  fi

  local output="${vSOLOS_OUTPUT:-"background"}"
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
  if [[ ${vSELF_LOG_BARE_LOG} = true ]]; then
    args=(--level "${level}" "${msg}")
  else
    args=(--time "kitchen" --structured --level "${level}" "${msg}")
    pkg.gum log --level.foreground "$(log._get_level_color "${level}")" --file "${vSTATIC_LOG_FILEPATH}/logs.txt" "${args[@]}" "${source_args[@]}" "${date_args[@]}"
  fi
  if [[ $level = "fatal" ]] || [[ $debug = true ]] || [[ $debug -eq 1 ]] || [[ $output != "background" ]]; then
    pkg.gum log --level.foreground "$(log._get_level_color "${level}")" "${args[@]}" "${source_args[@]}" "${date_args[@]}"
  fi
}
log.info() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "info" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log.info failed"
  fi
}
log.debug() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "debug" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log.debug failed"
  fi
}
log.error() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "error" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log.error failed"
  fi
}
log.fatal() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "fatal" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log.fatal failed"
  fi
}
log.warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "warn" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log.warn failed"
  fi
}
log.use_minimal() {
  vSELF_LOG_BARE_LOG=true
}
log.use_full() {
  vSELF_LOG_BARE_LOG=true
}
