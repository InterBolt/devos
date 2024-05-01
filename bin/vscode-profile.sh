#!/usr/bin/env bash

shopt -s extdebug

ENTRY_DIR="${PWD}"
PROXY_LIB_PATH="${HOME}/.solos/src/bin/proxy-lib.sh"

if [[ ! ${ENTRY_DIR} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
else
  cd "${ENTRY_DIR}" || exit 1
fi

PS1='\[\033[01;32m\]solos\[\033[00m\]:\[\033[01;34m\]'"\${ENTRY_DIR/\$HOME/~}"'\[\033[00m\]$ '

if [[ -s ${PROXY_LIB_PATH} ]]; then
  . "${PROXY_LIB_PATH}" || exit 1
else
  echo "${PROXY_LIB_PATH} was not found." >&2
  exit 1
fi

first_run=true

implement_proxy() {
  local cmd=$1
  shift
  if [[ ${cmd} = "exit" ]]; then
    return 0
  fi
  if [[ ${cmd} = "clear" ]]; then
    return 0
  fi
  if [[ ${cmd} = "code "* ]]; then
    return 0
  fi
  if [[ ${cmd} = "git "* ]]; then
    return 0
  fi
  if [[ ${first_run} = true ]]; then
    cd "${ENTRY_DIR}" || exit 1
    first_run=false
  fi
  if [[ ${cmd} = "cd "* ]] || [[ ${cmd} = "cd" ]] || [[ ${cmd} = "pushd "* ]] || [[ ${cmd} = "popd" ]]; then
    eval "${cmd} $@"
    if [[ ! ${PWD} = "${HOME}/.solos"* ]]; then
      PS1='host\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/~}"'\[\033[00m\]$ '
    else
      PS1='\[\033[01;32m\]solos\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/~}"'\[\033[00m\]$ '
    fi
    return 1
  fi
  if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
    return 0
  fi
  run_cmd_in_docker "${cmd}" "$@"
  return 1
}

run_on_debug() {
  implement_proxy "${BASH_COMMAND}" "$@"
  local code=$?
  return ${code}
}

trap run_on_debug DEBUG
