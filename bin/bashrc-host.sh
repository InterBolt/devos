#!/usr/bin/env bash

shopt -s extdebug

__s__RAG_DIR="${HOME}/.solos/rag"
__s__RAG_CAPTURED="${__s__RAG_DIR}/captured"
__s__RAG_NOTES="${__s__RAG_DIR}/notes"
__s__ENTRY_DIR="${PWD}"
__s__LIB_PATH="${HOME}/.solos/src/bin/lib.sh"

if [[ ! ${__s__ENTRY_DIR} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
else
  cd "${__s__ENTRY_DIR}" || exit 1
fi

# We always initialize in the .solos directory.
PS1='\[\033[01;32m\]solos\[\033[00m\]:\[\033[01;34m\]'"\${__s__ENTRY_DIR/\$HOME/~}"'\[\033[00m\]$ '

# pull in the library we use to run the CLI in the docker container.
. "${__s__LIB_PATH}" || exit 1

__s__ran=false

__s__execute_in_container() {
  # Not sure why but on the initial run, the working directory is not set correctly.
  if [[ ${__s__ran} = false ]]; then
    cd "${__s__ENTRY_DIR}" || exit 1
    __s__ran=true
  fi

  # These commands should run on the host.
  if [[ ${BASH_COMMAND} = "exit" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "clear" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "code" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "code "* ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "which code" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "man code" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "help code" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "info code" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "git" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "git "* ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "which git" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "man git" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "help git" ]]; then
    return 0
  elif [[ ${BASH_COMMAND} = "info git" ]]; then
    return 0
  fi

  # We cheat and execute some of the "rag" commands from the host since
  # they are just opening files in vscode.
  if [[ ${BASH_COMMAND} = "rag notes" ]]; then
    local rag_notes_line_count="$(wc -l <"${__s__RAG_NOTES}")"
    code --goto "${__s__RAG_NOTES}:${rag_notes_line_count}"
    return 1
  fi
  if [[ ${BASH_COMMAND} = "rag captured" ]]; then
    local rag_captured_line_count="$(wc -l <"${__s__RAG_CAPTURED}")"
    code --goto "${__s__RAG_CAPTURED}:${rag_captured_line_count}"
    return 1
  fi

  # Determine if the command will modify the working directory.
  local will_modify_pwd=false
  if [[ ${BASH_COMMAND} = "cd "* ]]; then
    will_modify_pwd=true
  elif [[ ${BASH_COMMAND} = "pushd "* ]]; then
    will_modify_pwd=true
  elif [[ ${BASH_COMMAND} = "popd" ]]; then
    will_modify_pwd=true
  fi

  # The PS1 is different when we are in the .solos directory than when we are not.
  # This is important because we want to visually indicate when we are running commands
  # in the docker container vs on the host.
  if [[ ${will_modify_pwd} = true ]]; then
    eval "${BASH_COMMAND} $@"
    if [[ ! ${PWD} = "${HOME}/.solos"* ]]; then
      PS1='host\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/~}"'\[\033[00m\]$ '
    else
      PS1='\[\033[01;32m\]solos\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/~}"'\[\033[00m\]$ '
    fi
    return 1
  fi

  # Always run on the host when not inside the .solos directory.
  if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
    return 0
  fi

  containerized_run "${BASH_COMMAND}" "$@"
  return 1
}

trap '__s__execute_in_container' DEBUG
