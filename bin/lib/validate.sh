#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh
#
# Important: rely on the server type file over anything else to determine if a valid project dir.
# The server type file is created immediately upon launch and gives us the best chance of correctly
# determining that a folder is a solos project since early exits before the server type file is created
# are extremely unlikely.
#

lib.validate.repo() {
  local repo_dir="$1"
  local server_dir="$repo_dir/$vSTATIC_REPO_SERVERS_DIR/$vOPT_SERVER"
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
