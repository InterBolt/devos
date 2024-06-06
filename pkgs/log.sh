#!/usr/bin/env bash

log__no_print=false
log__filesize=0
log__logfile="${HOME}/.solos/data/log/master.log"

. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1

mkdir -p "$(dirname "${log__logfile}")"
if [[ ! -f ${log__logfile} ]]; then
  touch "${log__logfile}"
fi

log__filesize="$(du -k "${log__logfile}" | cut -f 1 || echo "")"
if [[ ${log__filesize} -gt 100000 ]]; then
  echo "${log__logfile} is growing large. Currently at ${log__filesize}Kb"
fi

log.to_hostname() {
  local filename="${1}"
  if [[ ${filename} != /* ]]; then
    filename="$(pwd)/${filename}"
  fi
  local host="$(cat "${HOME}/.solos/data/store/users_home_dir")"
  echo "${filename/${HOME}/${host}}"
}
log.base() {
  if [[ ! -f ${log__logfile} ]]; then
    if ! touch "${log__logfile}" &>/dev/null; then
      echo "Failed to create log file: ${log__logfile}"
      exit 1
    fi
  fi
  local debug=${DEBUG:-false}
  local level="${1}"
  shift
  local source="${1}"
  shift
  local msg="${1}"
  shift
  if [[ ${source} = "NULL"* ]]; then
    source=""
  fi
  if [[ ${level} = "tag" ]]; then
    echo "[TAG] date=$(date +"%Y-%m-%dT%H:%M:%S") ${msg}"
    return 0
  fi
  gum_shell_log "${log__no_print}" "${log__logfile}" "${level}" "${msg}" "${source}"
}

log.use_custom_logfile() {
  log__logfile="${1}"
  log__filesize="$(du -k "${log__logfile}" | cut -f 1 || echo "")"
  if [[ ${log__filesize} -gt 100000 ]]; then
    echo "${log__logfile} is growing large. Currently at ${log__filesize}Kb"
  fi
}
log.use_file_only() {
  log__no_print=true
}

# PUBLIC FUNCTIONS:

log_tag() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log.base "tag" "$(log.to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log_tag failed"
  fi
}
log_info() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log.base "info" "$(log.to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log_info failed"
  fi
}
log_debug() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log.base "debug" "$(log.to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log_debug failed"
  fi
}
log_error() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log.base "error" "$(log.to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log_error failed"
  fi
}
log_fatal() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log.base "fatal" "$(log.to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log_fatal failed"
  fi
}
log_warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log.base "warn" "$(log.to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log_warn failed"
  fi
}
