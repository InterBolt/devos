#!/usr/bin/env bash

. "${HOME}/.solos/repo/shared/lib.sh" || exit 1
. "${HOME}/.solos/repo/shared/log.sh" || exit 1
. "${HOME}/.solos/repo/shared/gum.sh" || exit 1

# bashrc_app.print_help() {
#   cat <<EOF

# USAGE: app <add|remove|list>

# DESCRIPTION:

# Create, remove, and view apps associated with the project ($(lib.checked_out_project)).

# COMMANDS:

# add <name>      - Add an app to the project.
# remove <name>   - Remove an app from the project.
# list            - List all apps associated with the project.

# EOF
# }
# bashrc_app.add() {
#   local app_name="${1}"
#   if [[ -z ${app_name} ]]; then
#     bashrc.log_error "Invalid usage: an app name is required."
#     return 1
#   fi
# }
# bashrc_app.remove() {
#   local app_name="${1}"
#   if [[ -z ${app_name} ]]; then
#     bashrc.log_error "Invalid usage: an app name is required."
#     return 1
#   fi
# }
# bashrc_app.list() {
#   bashrc.log_info "Apps associated with the project: $(lib.checked_out_project)"
# }
# bashrc_app.main() {
#   if [[ $# -eq 0 ]]; then
#     bashrc_app.print_help
#     return 0
#   fi
#   if bashrc.is_help_cmd "${1}"; then
#     bashrc_app.print_help
#     return 0
#   fi
#   if [[ ${1} = "add" ]]; then
#     bashrc_app.add "${2}"
#   elif [[ ${1} = "remove" ]]; then
#     bashrc_app.remove "${2}"
#   elif [[ ${1} = "list" ]]; then
#     bashrc_app.list
#   else
#     bashrc.log_error "Unexpected command: $1"
#     return 1
#   fi
# }
