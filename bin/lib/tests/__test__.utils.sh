#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin"

# shellcheck source=../utils.sh
. "lib/utils.sh"

__hook__.before_file() {
  log.info "__hook__.before_file"
  return 1
}

__hook__.after_file() {
  log.info "running __hook__.after_file"
  return 1
}

__hook__.before_fn() {
  log.info "running __hook__.before_fn $1"
  return 1
}

__hook__.after_fn() {
  log.info "running __hook__.after_fn $1"
  return 1
}

__hook__.after_fn_success() {
  log.info "__hook__.after_fn_success $1"
  return 1
}

__hook__.after_fn_fails() {
  log.info "__hook__.after_fn_fails $1"
  return 1
}

__hook__.after_file_success() {
  log.info "__hook__.after_file_success"
  return 1
}

__hook__.after_file_fails() {
  log.info "__hook__.after_file_fails"
  return 1
}

vPREV_CURL_ERR_MESSAGE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_RESPONSE=""

__test__.utils.curl() {
  log.info "utils.curl not implemented yet"
  return 1
}
__test__.utils.curl.allows_error_status_codes() {
  log.info "utils.curl.allows_error_status_codes not implemented yet"
  return 1
}
__test__.utils.date() {
  log.info "utils.date not implemented yet"
  return 1
}
__test__.utils.echo_line() {
  log.info "utils.echo_line not implemented yet"
  return 1
}
__test__.utils.exit_trap() {
  log.info "utils.exit_trap not implemented yet"
  return 1
}
__test__.utils.files_match_dir() {
  log.info "utils.files_match_dir not implemented yet"
  return 1
}
__test__.utils.generate_secret() {
  log.info "utils.generate_secret not implemented yet"
  return 1
}
__test__.utils.grep_global_vars() {
  log.info "utils.grep_global_vars not implemented yet"
  return 1
}
__test__.utils.template_variables() {
  log.info "utils.template_variables not implemented yet"
  return 1
}
__test__.utils.warn_with_delay() {
  log.info "utils.warn_with_delay not implemented yet"
  return 1
}
