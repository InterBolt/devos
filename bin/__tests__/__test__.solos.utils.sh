#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

 # shellcheck source=../solos.utils.sh
. "solos.utils.sh"

__hook__.before_file() {
  log.error "__hook__.before_file"
  return 1
}

__hook__.after_file() {
  log.error "running __hook__.after_file"
  return 1
}

__hook__.before_fn() {
  log.error "running __hook__.before_fn $1"
  return 1
}

__hook__.after_fn() {
  log.error "running __hook__.after_fn $1"
  return 1
}

__hook__.after_fn_success() {
  log.error "__hook__.after_fn_success $1"
  return 1
}

__hook__.after_fn_fails() {
  log.error "__hook__.after_fn_fails $1"
  return 1
}

__hook__.after_file_success() {
  log.error "__hook__.after_file_success"
  return 1
}

__hook__.after_file_fails() {
  log.error "__hook__.after_file_fails"
  return 1
}

vPREV_CURL_ERR_MESSAGE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_RESPONSE=""

__test__.utils.curl() {
  log.error "utils.curl not implemented yet"
  return 1
}

__test__.utils.curl.allows_error_status_codes() {
  log.error "utils.curl.allows_error_status_codes not implemented yet"
  return 1
}

__test__.utils.date() {
  log.error "utils.date not implemented yet"
  return 1
}

__test__.utils.echo_line() {
  log.error "utils.echo_line not implemented yet"
  return 1
}

__test__.utils.exit_trap() {
  log.error "utils.exit_trap not implemented yet"
  return 1
}

__test__.utils.files_match_dir() {
  log.error "utils.files_match_dir not implemented yet"
  return 1
}

__test__.utils.generate_secret() {
  log.error "utils.generate_secret not implemented yet"
  return 1
}

__test__.utils.grep_global_vars() {
  log.error "utils.grep_global_vars not implemented yet"
  return 1
}

__test__.utils.template_variables() {
  log.error "utils.template_variables not implemented yet"
  return 1
}

__test__.utils.warn_with_delay() {
  log.error "utils.warn_with_delay not implemented yet"
  return 1
}
