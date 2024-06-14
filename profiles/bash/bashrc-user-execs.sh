#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/shared/log.sh" || exit 1
. "${HOME}/.solos/src/shared/gum.sh" || exit 1

bashrc_user_execs.install() {
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
bashrc_user_execs.pre() {
  if bashrc.is_help_cmd "${1}"; then
    cat <<EOF
USAGE: preexex <add|remove|list>

DESCRIPTION:

Manage user-defined preexec functions that will run (in the order they are added) \
before any entered shell prompt. For use in \`~/.solos/rcfiles/.bashrc\`. \
Warning: some shell prompts (ie. \`cd\`, \`ls\`, etc) opt out of pre/post \
exec functions.
EOF
    return 0
  fi
  local cmd="${1}"
  if [[ -z ${cmd} ]]; then
    log.error "No command supplied to \`preexec\`."
    return 1
  fi
  if [[ ${cmd} = "list" ]]; then
    echo "${user_preexecs[@]}"
    return 0
  fi
  if [[ ${cmd} = "add" ]]; then
    local fn="${1}"
    if [[ -z ${fn} ]]; then
      log.error "Invalid usage: missing function name"
      return 1
    fi
    if ! declare -f "${fn}" >/dev/null; then
      log.error "Invalid usage: function '${fn}' not found"
      return 1
    fi
    if [[ " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
      log.error "Invalid usage: function '${fn}' already exists in user_preexecs"
      return 1
    fi
    user_preexecs+=("${fn}")
    return 0
  fi
  if [[ ${cmd} = "remove" ]]; then
    local fn="${1}"
    if [[ ! " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
      log.error "Invalid usage: preexec: function '${fn}' not found in user_preexecs"
      return 1
    fi
    user_preexecs=("${user_preexecs[@]/${fn}/}")
    return 0
  fi
  log.error "Invalid usage: unknown command: ${cmd} supplied to \`preexec\`."
}
bashrc_user_execs.post() {
  if bashrc.is_help_cmd "${1}"; then
    cat <<EOF
USAGE: postexec <add|remove|list>

DESCRIPTION:

Manage user-defined postexec functions that will run (in the order they are added) \
after the execution of any submitted shell prompts. \
For use in \`~/.solos/rcfiles/.bashrc\`. Warning: some shell prompts \
(ie. \`cd\`, \`ls\`, etc) opt out of pre/post exec functions.
EOF
    return 0
  fi

  local cmd="${1}"
  if [[ -z ${cmd} ]]; then
    log.error "No command supplied to \`preexec\`."
    return 1
  fi

  if [[ ${cmd} = "list" ]]; then
    echo "${user_postexecs[@]}"
    return 0
  fi
  if [[ ${cmd} = "add" ]]; then
    local fn="${1}"
    if [[ -z ${fn} ]]; then
      log.error "Invalid usage: missing function name"
      return 1
    fi
    if ! declare -f "${fn}" >/dev/null; then
      log.error "Invalid usage: function '${fn}' not found"
      return 1
    fi
    if [[ " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
      log.error "Invalid usage: function '${fn}' already exists in user_postexecs"
      return 1
    fi
    user_postexecs+=("${fn}")
    return 0
  fi
  if [[ ${cmd} = "remove" ]]; then
    local fn="${1}"
    if [[ ! " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
      log.error "Invalid usage: postexec: function '${fn}' not found in user_postexecs" >&2
      return 1
    fi
    user_postexecs=("${user_postexecs[@]/${fn}/}")
    return 0
  fi
  log.error "Invalid usage: unknown command: ${cmd} supplied to \`postexec\`." >&2
}
bashrc_user_execs.main() {
  local lifecycle="${1}"
  if [[ -z ${lifecycle} ]]; then
    log.error "Unexpected error: missing lifecycle arg (\"pre\" or \"post\") in bashrc_user_execs.main."
    return 1
  fi
  shift
  if [[ ${lifecycle} = "pre" ]]; then
    bashrc_user_execs.pre "${@}"
    return $?
  fi
  if [[ ${lifecycle} = "post" ]]; then
    bashrc_user_execs.post "${@}"
    return $?
  fi
  log.error "Unexpected error: unknown lifecycle arg (${lifecycle}) in bashrc_user_execs.main."
}
