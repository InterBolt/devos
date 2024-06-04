#!/usr/bin/env bash

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1

profile_user_execs.install() {
  local failed=false
  if ! declare -p user_preexecs >/dev/null 2>&1; then
    log_error "Unexpected error: \`user_preexecs\` is not defined"
    failed=true
  fi
  if ! declare -p user_postexecs >/dev/null 2>&1; then
    log_error "Unexpected error: \`user_postexecs\` is not defined"
    failed=true
  fi
  if [[ ${failed} = true ]]; then
    profile.error_press_enter
  fi
}
profile_user_execs.pre() {
  if profile.is_help_cmd "${1}"; then
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
    log_error "No command supplied to \`preexec\`."
    return 1
  fi
  if [[ ${cmd} = "list" ]]; then
    echo "${user_preexecs[@]}"
    return 0
  fi
  if [[ ${cmd} = "add" ]]; then
    local fn="${1}"
    if [[ -z ${fn} ]]; then
      log_error "Invalid usage: missing function name"
      return 1
    fi
    if ! declare -f "${fn}" >/dev/null; then
      log_error "Invalid usage: function '${fn}' not found"
      return 1
    fi
    if [[ " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
      log_error "Invalid usage: function '${fn}' already exists in user_preexecs"
      return 1
    fi
    user_preexecs+=("${fn}")
    return 0
  fi
  if [[ ${cmd} = "remove" ]]; then
    local fn="${1}"
    if [[ ! " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
      log_error "Invalid usage: preexec: function '${fn}' not found in user_preexecs"
      return 1
    fi
    user_preexecs=("${user_preexecs[@]/${fn}/}")
    return 0
  fi
  log_error "Invalid usage: unknown command: ${cmd} supplied to \`preexec\`."
}
profile_user_execs.post() {
  if profile.is_help_cmd "${1}"; then
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
    log_error "No command supplied to \`preexec\`."
    return 1
  fi

  if [[ ${cmd} = "list" ]]; then
    echo "${user_postexecs[@]}"
    return 0
  fi
  if [[ ${cmd} = "add" ]]; then
    local fn="${1}"
    if [[ -z ${fn} ]]; then
      log_error "Invalid usage: missing function name"
      return 1
    fi
    if ! declare -f "${fn}" >/dev/null; then
      log_error "Invalid usage: function '${fn}' not found"
      return 1
    fi
    if [[ " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
      log_error "Invalid usage: function '${fn}' already exists in user_postexecs"
      return 1
    fi
    user_postexecs+=("${fn}")
    return 0
  fi
  if [[ ${cmd} = "remove" ]]; then
    local fn="${1}"
    if [[ ! " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
      log_error "Invalid usage: postexec: function '${fn}' not found in user_postexecs" >&2
      return 1
    fi
    user_postexecs=("${user_postexecs[@]/${fn}/}")
    return 0
  fi
  log_error "Invalid usage: unknown command: ${cmd} supplied to \`postexec\`." >&2
}
profile_user_execs.main() {
  local lifecycle="${1}"
  if [[ -z ${lifecycle} ]]; then
    log_error "Unexpected error: missing lifecycle arg (\"pre\" or \"post\") in profile_user_execs.main."
    return 1
  fi
  shift
  if [[ ${lifecycle} = "pre" ]]; then
    profile_user_execs.pre "${@}"
    return $?
  fi
  if [[ ${lifecycle} = "post" ]]; then
    profile_user_execs.post "${@}"
    return $?
  fi
  log_error "Unexpected error: unknown lifecycle arg (${lifecycle}) in profile_user_execs.main."
}
