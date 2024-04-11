#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=solos.sh
. "shared/empty.sh"
# shellcheck source=solos.utils.sh
. "shared/empty.sh"
# shellcheck source=shared/static.sh
. "shared/empty.sh"

validate.throw_if_dangerous_dir() {
  if [ "${vCLI_OPT_DIR}" == "$HOME" ]; then
    log.error "Danger: you are trying to wipe the home directory. Exiting."
    exit 1
  fi
  if [[ "$HOME" == "${vCLI_OPT_DIR}"* ]]; then
    log.error "Danger: you are trying to wipe a parent directory of your home directory. Exiting."
    exit 1
  fi
  if [ "${vSTATIC_MY_CONFIG_ROOT}" == "${vCLI_OPT_DIR}" ]; then
    log.error "Danger: this would wipe the solos config directory. Exiting."
    exit 1
  fi
}
#
# Important: rely on the server type file over anything else to determine if a valid project dir.
# The server type file is created immediately upon launch and gives us the best chance of correctly
# determining that a folder is a solos project since early exits before the server type file is created
# are extremely unlikely.
#
validate.throw_on_nonsolos() {
  validate.throw_if_dangerous_dir

  if [ ! -d "${vCLI_OPT_DIR}" ]; then
    log.error "Invalid directory supplied for --dir flag: ${vCLI_OPT_DIR}. Exiting."
    exit 1
  fi
  if [ ! -f "${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME}" ]; then
    log.error "The supplied directory does not contain a ${vSTATIC_SERVER_TYPE_FILENAME} file. Exiting."
    exit 1
  fi
}
validate.throw_on_nonsolos_dir() {
  validate.throw_if_dangerous_dir

  if [ -d "${vCLI_OPT_DIR}" ] && [ ! -f "${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME}" ]; then
    log.error "The supplied directory already exists and does not contain a ${vSTATIC_SERVER_TYPE_FILENAME} file. Exiting."
  fi
}
validate.throw_if_missing_installed_commands() {
  for cmd in "${vSTATIC_DEPENDENCY_COMMANDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      log.error "pre-check failed. Install \"$cmd\" to your path and try again."
      exit 1
    fi
  done
}
validate.docker_host_running() {
  if [ "$vSTATIC_HOST" != "local" ]; then
    log.error "this command must be run from the local host. Exiting."
    exit 1
  fi
  if [ -z "$vENV_SOLOS_ID" ]; then
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
validate.validate_project_repo() {
  local repo_dir="$1"
  local server_dir="$repo_dir/$vSTATIC_REPO_SERVERS_DIR/$vCLI_OPT_SERVER"
  local server_launch_dir="$server_dir/$vSTATIC_LAUNCH_DIRNAME"
  local bin_launch_dir="$repo_dir/$vSTATIC_BIN_LAUNCH_DIR"
  if [ ! -d "$repo_dir" ]; then
    log.error "The repo directory does not exist: $repo_dir. Exiting."
    exit 1
  fi
  if [ ! -d "$repo_dir/.git" ]; then
    log.error "Unexpected error: the repo directory does not contain a .git directory. Exiting."
    exit 1
  fi
  if [ ! -d "$server_dir" ]; then
    log.error "Unexpected error: the server directory does not exist: $server_dir. Exiting."
    exit 1
  fi
  if [ ! -d "$server_launch_dir" ]; then
    log.error "Unexpected error: the server's launch directory does not exist: $server_launch_dir. Exiting."
    exit 1
  fi
  if [ ! -d "$bin_launch_dir" ]; then
    log.error "Unexpected error: the bin launch directory does not exist: $bin_launch_dir. Exiting."
    exit 1
  fi
  if ! utils.template_variables "$bin_launch_dir" "dry" "allow_empty" 2>&1; then
    log.error "bad variables used in: $bin_launch_dir"
    exit 1
  fi
}
validate.checked_out_server_and_dir() {
  if [ -z "$vCLI_OPT_DIR" ]; then
    vCLI_OPT_DIR="$(cache.get "checked_out")"
    if [ -z "$vCLI_OPT_DIR" ]; then
      log.error "No directory supplied or checked out in the cache. Please supply a --dir."
      exit 1
    fi
    log.debug "set \$vCLI_OPT_DIR= $vCLI_OPT_DIR"
  fi
  if [ -z "$vCLI_OPT_SERVER" ]; then
    log.error "Unexpected error: couldn't find a server type from either the --server flag or the checked out directory."
    exit 1
  fi
}
