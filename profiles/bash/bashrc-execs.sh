#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/shared/log.sh" || exit 1
. "${HOME}/.solos/src/shared/gum.sh" || exit 1

bashrc_execs.get_help() {
  local lifecycle="${1}"
  local when=""
  if [[ ${lifecycle} = "preexec" ]]; then
    when="before"
  fi
  if [[ ${lifecycle} = "postexec" ]]; then
    when="after"
  fi
  if [[ -z ${when} ]]; then
    log.error "Unexpected error: lifecycle ${lifecycle}. Cannot generate the help documentation."
    return 1
  fi
  cat <<EOF

USAGE: ${lifecycle} <add|remove|list|clear>

DESCRIPTION:

Manage a list of functions that will run (in the order they are added) \
${when} any entered entered shell prompt (can contain multiple BASH_COMMAND(s) in a single entered prompt). For use in \`~/.solos/rcfiles/.bashrc\`.

COMMANDS:

add <function_name> - Add a function to the ${lifecycle} list.
remove <function_name> - Remove a function from the ${lifecycle} list.
list - List all functions in the ${lifecycle} list.

NOTES:

(1) When an entered shell prompt matches one of [$(bashrc.opted_out_shell_prompts | xargs)], \
the ${lifecycle} functions will not run.
(2) The ${lifecycle} functions will run in the order they are added.

EOF
}
bashrc_execs.already_exists() {
  local lifecycle="${1}"
  local fn="${2}"
  if [[ ${lifecycle} = "preexec" ]] && [[ " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
    log.warn "The preexec fn: '${fn}' already exists in user_preexecs. Nothing to add."
    return 0
  fi
  if [[ ${lifecycle} = "postexec" ]] && [[ " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
    log.warn "The postexec fn: '${fn}' already exists in user_postexecs. Nothing to add."
    return 0
  fi
  return 1
}
bashrc_execs.doesnt_exist() {
  local lifecycle="${1}"
  local fn="${2}"
  if [[ ${lifecycle} = "preexec" ]] && [[ ! " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
    log.warn "The preexec fn: '${fn}' not found in user_preexecs. Nothing to remove."
    return 0
  fi
  if [[ ${lifecycle} = "postexec" ]] && [[ ! " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
    log.warn "The postexec fn: '${fn}' not found in user_postexecs. Nothing to remove."
    return 0
  fi
  return 1
}
bashrc_execs.install() {
  local failed=false
  if ! declare -p user_preexecs >/dev/null 2>&1; then
    log.error "Unexpected error: \`user_preexecs\` is not defined"
    failed=true
  fi
  if ! declare -p user_postexecs >/dev/null 2>&1; then
    log.error "Unexpected error: \`user_postexecs\` is not defined"
    failed=true
  fi
  if [[ ${failed} = true ]]; then
    bashrc.error_press_enter
  fi
}
# Uses lots of eval to allow dynamic manipulations of the user_preexecs and user_postexecs arrays.
bashrc_execs.main() {
  local lifecycle="${1}"
  local cmd="${2}"
  local fn="${3}"
  if bashrc.is_help_cmd "${cmd}"; then
    bashrc_execs.get_help "${lifecycle}"
    return 0
  fi
  if [[ -z ${cmd} ]]; then
    log.error "Invalid usage: no command supplied to \`${lifecycle}\`."
    bashrc_execs.get_help "${lifecycle}"
    return 1
  fi
  if [[ ${cmd} = "list" ]]; then
    eval "echo \"\${user_${lifecycle}s[@]}\""
    return 0
  fi
  if [[ ${cmd} = "clear" ]]; then
    eval "user_${lifecycle}s=()"
    return 0
  fi
  if [[ ${cmd} = "remove" ]]; then
    if [[ -z ${fn} ]]; then
      log.error "Invalid usage: missing function name"
      return 1
    fi
    if bashrc_execs.doesnt_exist "${fn}"; then
      log.error "Nothing to remove - '${fn}' does not exist in user_${lifecycle}s."
      return 1
    fi
    eval "user_${lifecycle}s=(\"${lifecycle}s[@]/${fn}/\")"
    return 0
  fi
  if [[ ${cmd} = "add" ]]; then
    if [[ -z ${fn} ]]; then
      log.error "Invalid usage: missing function name"
      return 1
    fi
    if bashrc_execs.already_exists "${fn}"; then
      log.error "Nothing to add - '${fn}' already exists in user_${lifecycle}s."
      return 1
    fi
    eval "user_${lifecycle}s=(\"${lifecycle}s[@]/${fn}/\")"
    return 0
  fi
  log.error "Invalid usage: unknown command: ${cmd} supplied to \`${lifecycle}\`."
}
