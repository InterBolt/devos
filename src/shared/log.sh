#!/usr/bin/env bash

. "${HOME}/.solos/repo/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/repo/src/shared/gum.sh" || exit 1

log__use_container_paths=false
log__filesize=0
log__logfile=""

log._install() {
  if [[ -z ${log__logfile} ]]; then
    return 1
  fi
  if [[ ! -f ${log__logfile} ]]; then
    mkdir -p "$(dirname "${log__logfile}")"
    touch "${log__logfile}"
  fi
  local logsize="$(du -k "${log__logfile}" | cut -f 1 || echo "")"
  if [[ ${logsize} -gt 100000 ]]; then
    echo "${log__logfile} is growing large. Currently at ${logsize}Kb"
  fi
}
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
    echo "Unexpected error: no log file was found." >&2
    return 1
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
  gum.log "true" "${log__logfile}" "${level}" "${msg}" "${source}"
}

# PUBLIC FUNCTIONS:

log.use() {
  log__logfile="${1}"
  log._install
}
log.use_container_paths() {
  log__use_container_paths=true
}
log.info() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "info" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "Unexpected error: log.info failed"
  fi
}
log.debug() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "debug" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "Unexpected error: log.debug failed"
  fi
}
log.error() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "error" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "Unexpected error: log.error failed"
  fi
}
log.fatal() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "fatal" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "Unexpected error: log.fatal failed"
  fi
}
log.warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! log._base "warn" "$(log._to_hostname "${filename}"):${linenumber}" "$@"; then
    echo "log.warn failed"
  fi
}
