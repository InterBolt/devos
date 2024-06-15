#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/shared/log.sh" || exit 1
. "${HOME}/.solos/src/shared/gum.sh" || exit 1

bashrc_panic__dir="$(lib.panic_dir_path)"
bashrc_panic__muted=false

bashrc_panics.print() {
  if [[ ${bashrc_panic__muted} = true ]]; then
    echo ""
    return 0
  fi
  local panic_messages="$(lib.panics_print_all)"
  if [[ -z ${panic_messages} ]]; then
    return 1
  fi
  local newline=$'\n'
  gum.danger_box "${panic_messages}${newline}${newline}Please report the issue at https://github.com/interbolt/solos/issues."
  return 0
}
bashrc_panics.install() {
  if bashrc_panics.print; then
    local should_proceed="$(gum.confirm_ignore_panic)"
    if [[ ${should_proceed} = true ]]; then
      return 1
    else
      exit 1
    fi
  fi
  return 0
}
bashrc_panics.print_help() {
  cat <<EOF

USAGE: panic <review|clear|mute>

DESCRIPTION:

A command to review "panic" files. \
A panic file contains a message, a severity level, and a timestamp.

Panic files at: ${bashrc_panic__dir}

COMMANDS:

review       - Review the panic messages.
clear        - Clear all panic messages.
mute         - Mute the panic messages.

EOF
}
bashrc_panics.main() {
  if [[ $# -eq 0 ]]; then
    bashrc_panics.print_help
    return 0
  fi
  if bashrc.is_help_cmd "$1"; then
    bashrc_panics.print_help
    return 0
  fi
  if [[ $1 = "review" ]]; then
    if bashrc_panics.print; then
      return 0
    else
      log.info "No panic message was found."
      return 0
    fi
  elif [[ $1 = "clear" ]]; then
    lib.panics_clear
    return 0
  elif [[ $1 = "mute" ]]; then
    bashrc_panic__muted=true
    return 0
  else
    log.error "Invalid command: $1"
    bashrc_panics.print_help
    return 1
  fi
}
