#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

lib.validate.throw_if_dangerous_dir() {
  if [[ ${vCLI_OPT_DIR} = "${HOME}" ]]; then
    log.error "Danger: can't create a project from your home directory. Exiting."
    exit 1
  fi
  if [[ ${HOME} = "${vCLI_OPT_DIR}"* ]]; then
    log.error "Danger: can't create a project in a parent directory of your home directory. Exiting."
    exit 1
  fi
  if [[ ${vSTATIC_MY_CONFIG_ROOT} = "${vCLI_OPT_DIR}"* ]]; then
    log.error "Danger: can't create a project in a parent directory of your config directory. Exiting."
    exit 1
  fi
}
#
# Important: rely on the server type file over anything else to determine if a valid project dir.
# The server type file is created immediately upon launch and gives us the best chance of correctly
# determining that a folder is a solos project since early exits before the server type file is created
# are extremely unlikely.
#
lib.validate.throw_on_nonsolos() {
  lib.validate.throw_if_dangerous_dir

  if [[ ! -d ${vCLI_OPT_DIR} ]]; then
    log.error "Invalid directory supplied for --dir flag: ${vCLI_OPT_DIR}. Exiting."
    exit 1
  fi
  if [[ ! -f ${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME} ]]; then
    log.error "The supplied directory does not contain a ${vSTATIC_SERVER_TYPE_FILENAME} file. Exiting."
    exit 1
  fi
}

lib.validate.throw_on_nonsolos_dir() {
  lib.validate.throw_if_dangerous_dir

  if [[ -d ${vCLI_OPT_DIR} ]] && [[ ! -f ${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME} ]]; then
    log.error "The supplied directory already exists and does not contain a ${vSTATIC_SERVER_TYPE_FILENAME} file. Exiting."
  fi
}

lib.validate.throw_if_missing_installed_commands() {
  for cmd in "${vSTATIC_DEPENDENCY_COMMANDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      log.error "pre-check failed. Install \"$cmd\" to your path and try again."
      exit 1
    fi
  done
}

lib.validate.docker_host_running() {
  if [[ $vSTATIC_HOST != "local" ]]; then
    log.error "this command must be run from the local host. Exiting."
    exit 1
  fi
  if [[ -z $vENV_SOLOS_ID ]]; then
    log.error "no solos id found. this is stored at $vSTATIC_MY_CONFIG_ROOT/$vSTATIC_SERVER_TYPE_FILENAME"
    exit 1
  fi
  if ! docker info &>/dev/null; then
    log.error "docker desktop not running."
    exit 1
  fi
  if ! COMPOSE_PROJECT_NAME="solos-$vENV_SOLOS_ID" docker-compose ps &>/dev/null; then
    log.error "the compose project \`solos-$vENV_SOLOS_ID\` is not running."
    exit 1
  fi
}

lib.validate.repo() {
  local repo_dir="$1"
  local server_dir="$repo_dir/$vSTATIC_REPO_SERVERS_DIR/$vCLI_OPT_SERVER"
  local server_launch_dir="$server_dir/$vSTATIC_LAUNCH_DIRNAME"
  local bin_launch_dir="$repo_dir/$vSTATIC_BIN_LAUNCH_DIR"
  if [[ ! -d $repo_dir ]]; then
    log.error "The repo directory does not exist: $repo_dir. Exiting."
    exit 1
  fi
  if [[ ! -d $repo_dir/.git ]]; then
    log.error "Unexpected error: the repo directory does not contain a .git directory. Exiting."
    exit 1
  fi
  if [[ ! -d $server_dir ]]; then
    log.error "Unexpected error: the server directory does not exist: $server_dir. Exiting."
    exit 1
  fi
  if [[ ! -d $server_launch_dir ]]; then
    log.error "Unexpected error: the server's launch directory does not exist: $server_launch_dir. Exiting."
    exit 1
  fi
  if [[ ! -d $bin_launch_dir ]]; then
    log.error "Unexpected error: the bin launch directory does not exist: $bin_launch_dir. Exiting."
    exit 1
  fi
}

lib.validate.checked_out() {
  if [[ -z $vCLI_OPT_DIR ]]; then
    vCLI_OPT_DIR="$(lib.cache.get "checked_out")"
    if [[ -z $vCLI_OPT_DIR ]]; then
      log.error "No directory supplied or checked out in the lib.cache. Please supply a --dir."
      exit 1
    fi
  fi
  if [[ -z $vCLI_OPT_SERVER ]]; then
    log.error "Unexpected error: couldn't infer a server type from the supplied directory: ${vCLI_OPT_DIR}. Exiting."
    exit 1
  fi
}
