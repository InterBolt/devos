#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/pkgs/log.sh" || exit 1
. "${HOME}/.solos/src/bash/pkgs/gum.sh" || exit 1

profile_panic__dir="${HOME}/.solos/data/panics"
profile_panic__muted=false

profile_panics.print() {
  if [[ ${profile_panic__muted} = true ]]; then
    echo ""
    return 0
  fi
  local panic_messages="$(lib.panics_print_all)"
  if [[ -z ${panic_messages} ]]; then
    return 1
  fi
  local newline=$'\n'
  gum_danger_box "${panic_messages}${newline}${newline}Please report the issue at https://github.com/interbolt/solos/issues."
  return 0
}
profile_panics.install() {
  if profile_panics.print; then
    local should_proceed="$(gum_confirm_ignore_panic)"
    if [[ ${should_proceed} = true ]]; then
      return 1
    else
      exit 1
    fi
  fi
  return 0
}
profile_panics.print_help() {
  cat <<EOF

USAGE: panic <review|clear|mute>

DESCRIPTION:

A command to review "panic" files. \
A panic file contains a message, a severity level, and a timestamp.

Panic files at: ${profile_panic__dir}

COMMANDS:

review       - Review the panic messages.
clear        - Clear all panic messages.
mute         - Mute the panic messages.

EOF
}
profile_panics.main() {
  if [[ $# -eq 0 ]]; then
    profile_panics.print_help
    return 0
  fi
  if profile.is_help_cmd "$1"; then
    profile_panics.print_help
    return 0
  fi
  if [[ $1 = "review" ]]; then
    if profile_panics.print; then
      return 0
    else
      log_info "No panic message was found."
      return 0
    fi
  elif [[ $1 = "clear" ]]; then
    lib.panics_clear
    return 0
  elif [[ $1 = "mute" ]]; then
    profile_panic__muted=true
    return 0
  else
    log.error "Invalid command: $1"
    profile_panics.print_help
    return 1
  fi
}
