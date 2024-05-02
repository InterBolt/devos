#!/usr/bin/env bash

shopt -s extdebug

vprofENTRY_DIR="${PWD}"
vprofPROXY_LIB_PATH="${HOME}/.solos/src/bin/proxy-lib.sh"

if [[ ! ${vprofENTRY_DIR} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
else
  cd "${vprofENTRY_DIR}" || exit 1
fi

# We always initialize in the .solos directory.
PS1='\[\033[01;32m\]solos\[\033[00m\]:\[\033[01;34m\]'"\${vprofENTRY_DIR/\$HOME/~}"'\[\033[00m\]$ '

# pull in the library we use to run the CLI in the docker container.
. "${vprofPROXY_LIB_PATH}" || exit 1

___ran=false

docker_proxy() {
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

  # Not sure why but on the initial run, the working directory is not set correctly.
  if [[ ${___ran} = false ]]; then
    cd "${vprofENTRY_DIR}" || exit 1
    ___ran=true
  fi

  local will_modify_pwd=false
  # These commands manipulate our working directory and need to be run on the host.
  if [[ ${BASH_COMMAND} = "cd "* ]]; then
    will_modify_pwd=true
  elif [[ ${BASH_COMMAND} = "pushd "* ]]; then
    will_modify_pwd=true
  elif [[ ${BASH_COMMAND} = "popd" ]]; then
    will_modify_pwd=true
  fi

  if [[ ${will_modify_pwd} = true ]]; then
    eval "${BASH_COMMAND} $@"
    # Visually differ the prompt to indicate where commands are being run.
    # Outside of mounted volume, commands run on the host. Within - we run them in the
    # docker container.
    if [[ ! ${PWD} = "${HOME}/.solos"* ]]; then
      PS1='host\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/~}"'\[\033[00m\]$ '
    else
      PS1='\[\033[01;32m\]solos\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/~}"'\[\033[00m\]$ '
    fi
    return 1
  fi

  # Returning 0 will allow the original command to run.
  if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
    return 0
  fi

  # This will run the command in the docker container and stop the original command from running.
  run_cmd_in_docker "${BASH_COMMAND}" "$@"
  return 1
}

trap 'docker_proxy' DEBUG
