#!/usr/bin/env bash

set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin" || exit 1

# shellcheck source=../utils.sh
. "lib/utils.sh"

__hook__.before_file() {
  log.error "__hook__.before_file"
  return 0
}

__hook__.after_file() {
  log.error "running __hook__.after_file"
  return 0
}

__hook__.before_fn() {
  log.error "running __hook__.before_fn $1"
  return 0
}

__hook__.after_fn() {
  log.error "running __hook__.after_fn $1"
  return 0
}

__hook__.after_fn_success() {
  log.error "__hook__.after_fn_success $1"
  return 0
}

__hook__.after_fn_fails() {
  log.error "__hook__.after_fn_fails $1"
  return 0
}

__hook__.after_file_success() {
  log.error "__hook__.after_file_success"
  return 0
}

__hook__.after_file_fails() {
  log.error "__hook__.after_file_fails"
  return 0
}

vPREV_CURL_ERR_MESSAGE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_RESPONSE=""
vSTATIC_LOG_FILEPATH=""
vENTRY_LOG_LINE_COUNT=""
vENTRY_START_SECONDS=""
vENTRY_FOREGROUND=""

__test__.utils.curl() {
  log.error "utils.curl not implemented yet"
  return 0
}
__test__.utils.curl.allows_error_status_codes() {
  log.error "utils.curl.allows_error_status_codes not implemented yet"
  return 0
}
__test__.utils.full_date() {
  log.error "utils.date not implemented yet"
  return 0
}
__test__.utils.echo_line() {
  log.error "utils.echo_line not implemented yet"
  return 0
}
__test__.utils.exit_trap() {
  log.error "utils.exit_trap not implemented yet"
  return 0
}
__test__.utils.generate_secret() {
  log.error "utils.generate_secret not implemented yet"
  return 0
}
__test__.utils.template_variables() {
  log.error "utils.template_variables not implemented yet"
  return 0
}
__test__.utils.warn_with_delay() {
  log.error "utils.warn_with_delay not implemented yet"
  return 0
}
__test__.utils.spinner() {
  log.error "utils.spinner not implemented yet"
  return 0
}
__test__.utils.logdiff() {
  log.error "utils.logdiff not implemented yet"
  return 0
}
__test__.utils.do_task() {
  log.error "utils.do_task not implemented yet"
  return 0
}
