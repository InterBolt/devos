#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=../solos.flags.sh
source "solos.flags.sh"

__hook__.before_file() {
  log.info "__hook__.before_file"
}

__hook__.after_file() {
  log.info "running __hook__.after_file"
}

__hook__.before_fn() {
  log.info "running __hook__.before_fn $1"
}

__hook__.after_fn() {
  log.info "running __hook__.after_fn $1"
}

__hook__.after_fn_success() {
  log.info "__hook__.after_fn_success $1"
}

__hook__.after_fn_fails() {
  log.info "__hook__.after_fn_fails $1"
}

__hook__.after_file_success() {
  log.info "__hook__.after_file_success"
}

__hook__.after_file_fails() {
  log.info "__hook__.after_file_fails"
}

vCLI_PARSED_CMD=""
vCLI_PARSED_OPTIONS=""
vCLI_USAGE_ALLOWS_CMDS=""
vCLI_USAGE_ALLOWS_OPTIONS=""
vOTHER_VAR=""
vSOME_VAR=""
vSTATIC_DEFAULT_SERVER=""

__test__.flags._is_valid_help_command() {
  log.error "flags._is_valid_help_command not implemented yet"
  return 1
}

__test__.flags.command.backup.help() {
  log.error "flags.command.backup.help not implemented yet"
  return 1
}

__test__.flags.command.checkout.help() {
  log.error "flags.command.checkout.help not implemented yet"
  return 1
}

__test__.flags.command.code.help() {
  log.error "flags.command.code.help not implemented yet"
  return 1
}

__test__.flags.command.launch.help() {
  log.error "flags.command.launch.help not implemented yet"
  return 1
}

__test__.flags.command.precheck.help() {
  log.error "flags.command.precheck.help not implemented yet"
  return 1
}

__test__.flags.command.restore.help() {
  log.error "flags.command.restore.help not implemented yet"
  return 1
}

__test__.flags.command.status.help() {
  log.error "flags.command.status.help not implemented yet"
  return 1
}

__test__.flags.command.sync_config.help() {
  log.error "flags.command.sync_config.help not implemented yet"
  return 1
}

__test__.flags.command.tests.help() {
  log.error "flags.command.tests.help not implemented yet"
  return 1
}

__test__.flags.help() {
  log.error "flags.help not implemented yet"
  return 1
}

__test__.flags.parse_cmd() {
  log.error "flags.parse_cmd not implemented yet"
  return 1
}

__test__.flags.parse_requirements() {
  log.error "flags.parse_requirements not implemented yet"
  return 1
}

__test__.flags.somefn() {
  log.error "flags.somefn not implemented yet"
  return 1
}

__test__.flags.validate_options() {
  log.error "flags.validate_options not implemented yet"
  return 1
}
