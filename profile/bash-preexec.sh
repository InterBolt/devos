#!/usr/bin/env bash

shopt -s extdebug

prev_cmds=()

# __preexec__ps_fn__run() {
#   echo "PIPESTATUS COUNT: ${#PIPESTATUS[@]}" >&2
#   echo "BASH_COMMAND: ${BASH_COMMAND}" >&2
#   # echo "\${*} ${*}" >&2
#   # echo "\${BASH_COMMAND} ${BASH_COMMAND}" >&2

#   # # if the command is running within a pipe, echo some info here. I'm trying to understand this better
#   # echo "PIPESTATUS: ${PIPESTATUS[*]}" >&2
#   return 0
# }

# __init() {
#   local pipe_status_count="${#PIPESTATUS[@]}"
#   trap - DEBUG
#   echo "pipe_status_count: ${pipe_status_count}" >&2
#   trap '__preexec__ps_fn__run' DEBUG
# }

# PROMPT_COMMAND='__hmmm'
# trap '__preexec__ps_fn__run' DEBUG

# read every command before it is executed
#

__bash_preexec__fn__eval() {
  if [[ "$(type -t "${preexec}")" == 'function' ]]; then
    "${preexec}" "${*}"
  else
    eval "${*}"
  fi
}

__bash_preexec__var__trap_cmd() {
  if [[ "${BASH_COMMAND}" = "__bash_preexec__var__at_prompt=t" ]]; then
    return 0
  fi
  if [[ -n "${__bash_preexec__var__at_prompt+set}" ]]; then
    unset __bash_preexec__var__at_prompt
    __bash_preexec__var__history="$(history 1 | xargs | cut -d' ' -f2-)"
    trap - DEBUG
    __bash_preexec__fn__eval "${__bash_preexec__var__history}"
    trap '__bash_preexec__var__trap_cmd' DEBUG
  fi
  return 1
}

__bash_preexec__fn__main() {
  PROMPT_COMMAND='__bash_preexec__var__at_prompt=t'
  trap '__bash_preexec__var__trap_cmd' DEBUG
}
