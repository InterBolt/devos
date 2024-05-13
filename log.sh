#!/usr/bin/env bash

__log__var__filesize=0
__log__var__logfile="${HOME}/.solos/logs/cli.log"

. "${HOME}/.solos/src/pkg/gum.sh" || exit 1

mkdir -p "$(dirname "${__log__var__logfile}")"
if [[ ! -f ${__log__var__logfile} ]]; then
  touch "${__log__var__logfile}"
fi

__log__var__filesize="$(du -k "${__log__var__logfile}" | cut -f 1 || echo "")"
if [[ ${__log__var__filesize} -gt 5000 ]]; then
  echo "LOG FILE IS GROWING LARGE: ${__log__var__filesize}Kb"
fi

log._to_host_filename() {
  local filename="${1}"
  if [[ ${filename} != /* ]]; then
    filename="$(pwd)/${filename}"
  fi
  local host="$(cat "${HOME}/.solos/store/users_home_dir")"
  echo "${filename/${HOME}/${host}}"
}

log._get_level_color() {
  local level="${1}"
  case "${level}" in
  "info")
    echo "#3B78FF"
    ;;
  "rag")
    echo "#0F0"
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
__log__fn__base() {
  if [[ ! -f ${__log__var__logfile} ]]; then
    if ! touch "${__log__var__logfile}" &>/dev/null; then
      echo "Failed to create log file: ${__log__var__logfile}"
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

  if [[ ${level} = "rag" ]]; then
    echo "[RAG] date=$(date +"%Y-%m-%dT%H:%M:%S") ${msg}"
    return 0
  fi

  gum_bin log \
    --level.foreground "$(log._get_level_color "${level}")" \
    --file "${__log__var__logfile}" \
    --structured \
    --level "${level}" "${msg}" "${source_args[@]}" "${date_args[@]}"

  gum_bin log \
    --level.foreground "$(log._get_level_color "${level}")" \
    --structured \
    --level "${level}" "${msg}" "${source_args[@]}" "${date_args[@]}"
}
log_rag() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! __log__fn__base "rag" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log_rag failed"
  fi
}
log_info() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! __log__fn__base "info" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log_info failed"
  fi
}
log_debug() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! __log__fn__base "debug" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log_debug failed"
  fi
}
log_error() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! __log__fn__base "error" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log_error failed"
  fi
}
log_fatal() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! __log__fn__base "fatal" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log_fatal failed"
  fi
}
log_warn() {
  local filename="$(caller | cut -f 2 -d " ")"
  local linenumber="$(caller | cut -f 1 -d " ")"
  if ! __log__fn__base "warn" "$(log._to_host_filename "${filename}"):${linenumber}" "$@"; then
    echo "log_warn failed"
  fi
}
