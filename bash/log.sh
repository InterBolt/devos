#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/gum.sh" || exit 1

log__will_print=true
log__use_container_paths=false
log__filesize=0
log__logfile="${HOME}/.solos/data/log/master.log"

mkdir -p "$(dirname "${log__logfile}")"
if [[ ! -f ${log__logfile} ]]; then
  touch "${log__logfile}"
fi

log__filesize="$(du -k "${log__logfile}" | cut -f 1 || echo "")"
if [[ ${log__filesize} -gt 100000 ]]; then
  echo "${log__logfile} is growing large. Currently at ${log__filesize}Kb"
fi

log._to_hostname() {
  local filename="${1}"
  if [[ ${filename} != /* ]]; then
    filename="$(pwd)/${filename}"
  fi
  lib.use_host "${filename}"
}
log._correct_paths_in_msg() {
  local msg="${1}"
  if [[ ${log__use_container_paths} = true ]]; then
    echo "${msg}"
    return 0
  fi
  local home_dir_path="$(lib.home_dir_path)"
  if [[ -z "${home_dir_path}" ]]; then
    lib.panics_add "missing_home_dir" <<EOF
No reference to the user's home directory was found in the folder: ~/.solos/data/store.
EOF
    echo "${msg}"
    return 1
  fi
  local home_dir_path="$(lib.home_dir_path)"
  echo "${msg}" | sed -e "s|/root/|${home_dir_path}/|g" | sed -e "s|~/|${home_dir_path}/|g"
}
log._base() {
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
  msg="$(log._correct_paths_in_msg "${msg}")"
  if [[ ${level} = "tag" ]]; then
    echo "[TAG] date=$(date +"%Y-%m-%dT%H:%M:%S") ${msg}"
    return 0
  fi
  gum.shell_log "${log__will_print}" "${log__logfile}" "${level}" "${msg}" "${source}"
}

# PUBLIC FUNCTIONS:

log.use_custom_logfile() {
  log__logfile="${1}"
  log__filesize="$(du -k "${log__logfile}" | cut -f 1 || echo "")"
  if [[ ${log__filesize} -gt 100000 ]]; then
    echo "${log__logfile} is growing large. Currently at ${log__filesize}Kb"
  fi
}
log.use_file_only() {
  log__will_print=false
}
log.use_container_paths() {
  log__use_container_paths=true
}
log.info() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "info" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log.info failed"
  fi
}
log.debug() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "debug" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log.debug failed"
  fi
}
log.error() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "error" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log.error failed"
  fi
}
log.fatal() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "fatal" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log.fatal failed"
  fi
}
log.warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "warn" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log.warn failed"
  fi
}

log.info_notrace() {
  if ! log._base "info" "NULL" "$@"; then
    echo "log.info failed"
  fi
}
log.debug_notrace() {
  if ! log._base "debug" "NULL" "$@"; then
    echo "log.debug failed"
  fi
}
log.error_notrace() {
  if ! log._base "error" "NULL" "$@"; then
    echo "log.error failed"
  fi
}
log.fatal_notrace() {
  if ! log._base "fatal" "NULL" "$@"; then
    echo "log.fatal failed"
  fi
}
log.warn_notrace() {
  if ! log._base "warn" "NULL" "$@"; then
    echo "log.warn failed"
  fi
}
