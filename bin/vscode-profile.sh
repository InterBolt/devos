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

vprofRAN_ONCE=false

docker_proxy() {
  local cmd="${BASH_COMMAND}"
  shift

  # These commands should run on the host.
  if [[ ${BASH_COMMAND} = "exit" ]] ||
    [[ ${BASH_COMMAND} = "clear" ]] ||
    [[ ${BASH_COMMAND} = "code" ]] ||
    [[ ${BASH_COMMAND} = "code "* ]] ||
    [[ ${BASH_COMMAND} = "which code" ]] ||
    [[ ${BASH_COMMAND} = "man code" ]] ||
    [[ ${BASH_COMMAND} = "help code" ]] ||
    [[ ${BASH_COMMAND} = "info code" ]] ||
    [[ ${BASH_COMMAND} = "git" ]] ||
    [[ ${BASH_COMMAND} = "git "* ]] ||
    [[ ${BASH_COMMAND} = "which git" ]] ||
    [[ ${BASH_COMMAND} = "man git" ]] ||
    [[ ${BASH_COMMAND} = "help git" ]] ||
    [[ ${BASH_COMMAND} = "info git" ]]; then
    return 0
  fi

  # Not sure why but on the initial run, the working directory is not set correctly.
  if [[ ${vprofRAN_ONCE} = false ]]; then
    cd "${vprofENTRY_DIR}" || exit 1
    vprofRAN_ONCE=true
  fi

  # These commands manipulate our working directory and need to be run on the host.
  if [[ ${BASH_COMMAND} = "cd "* ]] ||
    [[ ${BASH_COMMAND} = "cd" ]] ||
    [[ ${BASH_COMMAND} = "pushd "* ]] ||
    [[ ${BASH_COMMAND} = "popd" ]]; then

    # Run the command on the host.
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

trap docker_proxy DEBUG
