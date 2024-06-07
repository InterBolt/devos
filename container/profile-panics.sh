#!/usr/bin/env bash

profile_panic__dir="${HOME}/.solos/data/panics"
profile_panic__muted=false

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1
. "${HOME}/.solos/src/pkgs/panics.sh" || exit 1

profile_panics.print() {
  if [[ ${profile_panic__muted} = true ]]; then
    return 0
  fi
  local panic_messages="$(panics_print_latest)"
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

Unlike error logs, which might pertain to resolved issue(s), \
the presence of panic files indicate a problem that needs immediate attention. \
SolOS will display a panic file's contents every chance it gets until the panic is cleared.

Panic files at: ${profile_panic__dir}

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
    panics_clear
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
