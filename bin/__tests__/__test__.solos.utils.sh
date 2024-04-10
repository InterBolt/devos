#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

 # shellcheck source=../solos.utils.sh
source "solos.utils.sh"

testhook.before_file() {
  log.info "testhook.before_file"
}

testhook.after_file() {
  log.info "running testhook.after_file"
}

testhook.before_fn() {
  log.info "running testhook.before_fn"
}

testhook.after_fn() {
  log.info "running testhook.after_fn"
}

testhook.after_fn_success() {
  log.info "testhook.after_fn_success"
}

testhook.after_fn_fails() {
  log.info "testhook.after_fn_fails"
}

testhook.after_file_success() {
  log.info "testhook.after_file_success"
}

testhook.after_file_fails() {
  log.info "testhook.after_file_fails"
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

__test__.utils.debug_dump_vars() {
  log.error "utils.debug_dump_vars not implemented yet"
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
