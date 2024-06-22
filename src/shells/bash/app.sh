#!/usr/bin/env bash

app.print_help() {
  cat <<EOF

USAGE: app <add|remove|list>

DESCRIPTION:

Create, remove, and view apps associated with the project ($(lib.checked_out_project)).

COMMANDS:

add <name>      - Add an app to the project.
remove <name>   - Remove an app from the project.
list            - List all apps associated with the project.

EOF
}
app.add() {
  local app_name="${1}"
  if [[ -z ${app_name} ]]; then
    shell.log_error "Invalid usage: an app name is required."
    return 1
  fi
}
app.remove() {
  local app_name="${1}"
  if [[ -z ${app_name} ]]; then
    shell.log_error "Invalid usage: an app name is required."
    return 1
  fi
}
app.list() {
  shell.log_info "Apps associated with the project: $(lib.checked_out_project)"
}
app.cmd() {
  if [[ $# -eq 0 ]]; then
    app.print_help
    return 0
  fi
  if lib.is_help_cmd "${1}"; then
    app.print_help
    return 0
  fi
  if [[ ${1} = "add" ]]; then
    app.add "${2}"
  elif [[ ${1} = "remove" ]]; then
    app.remove "${2}"
  elif [[ ${1} = "list" ]]; then
    app.list
  else
    shell.log_error "Unexpected command: $1"
    return 1
  fi
}
