#!/usr/bin/env bash

vSELF_LOG_ENTRY_DIR="${PWD}"

# We do sourcing this way to ensure the log functions are available anywhere we need them as a single import
# we also check if the pkg.gum command is available before sourcing pkg/__source__.sh because I don't want to blindly assume
# that the pkg/__source__.sh file idempotent.
cd "${HOME}/.solos/src/bin" || exit 1
. "${HOME}/.solos/src/bin/shared/static.sh" || exit 1
if ! command -v pkg.gum &>/dev/null; then
  . "${HOME}/.solos/src/bin/pkg/__source__.sh" || exit 1
fi
cd "${vSELF_LOG_ENTRY_DIR}" || exit 1

vSELF_LOG_BARE_LOG=false
vSELF_LOG_FILESIZE=0

mkdir -p "${vSTATIC_LOGS_DIR}"
if [[ ! -f ${vSTATIC_LOG_FILEPATH} ]]; then
  touch "${vSTATIC_LOG_FILEPATH}"
fi

vSELF_LOG_FILESIZE="$(du -k "${vSTATIC_LOG_FILEPATH}" | cut -f 1 || echo "")"
if [[ ${vSELF_LOG_FILESIZE} -gt 5000 ]]; then
  vSELF_LOG_BARE_LOG=true
  echo "LOG FILE IS GROWING LARGE: ${vSELF_LOG_FILESIZE}Kb"
fi

log._to_host_filename() {
  local filename="${1}"
  if [[ ${filename} != /* ]]; then
    filename="$(pwd)/${filename}"
  fi
  local host="$(cat "${vSTATIC_SOLOS_ROOT}/store/users_home_dir")"
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
  if [[ ! -f ${vSTATIC_LOG_FILEPATH} ]]; then
    if ! touch "${vSTATIC_LOG_FILEPATH}" &>/dev/null; then
      echo "Failed to create log file: ${vSTATIC_LOG_FILEPATH}"
      exit 1
    fi
  fi

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

  pkg.gum log \
    --level.foreground "$(log._get_level_color "${level}")" \
    --file "${vSTATIC_LOG_FILEPATH}" \
    --time "kitchen" \
    --structured \
    --level "${level}" "${msg}" "${source_args[@]}" "${date_args[@]}"

  pkg.gum log \
    --level.foreground "$(log._get_level_color "${level}")" \
    --structured \
    --level "${level}" "${msg}" "${source_args[@]}"
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
