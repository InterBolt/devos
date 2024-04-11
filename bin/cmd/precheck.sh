#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

subcmd.precheck.variables() {
  local entry_pwd="$PWD"
  cd "$vENTRY_BIN_DIR"
  local errored=false
  local files
  #
  # Lop through every solos lib file and check that
  # every referenced variable is defined in solos' global variables.
  #
  files=$(find . -type f -name "solos*")
  for file in $files; do
    local global_vars=$(lib.utils.grep_global_vars "$file")
    for global_var in $global_vars; do
      local result="$(declare -p "$global_var" &>/dev/null && echo "set" || echo "unset")"
      if [ "$result" == "unset" ]; then
        log.error "Unknown variable: $global_var used in $file"
        errored=true
      fi
    done
  done
  if [ "$errored" == true ]; then
    exit 1
  fi
  cd "$entry_pwd"
  log.info "test passed: all referenced global variables are defined."
}

subcmd.precheck.launchfiles() {
  local entry_pwd="$PWD"
  cd "${vSTATIC_RUNNING_REPO_ROOT}"
  #
  # Check that all the variables we use in the bin's .launch dir are defined
  # in solos' global variables.
  #
  lib.utils.template_variables "${vSTATIC_BIN_LAUNCH_DIR}" "dry" "allow_empty"
  cd "$entry_pwd"
  log.info "test passed: launchfiles are valid and match global variables."
  #
  # Check that the defualt server type exists
  #
  local servers_dir="${vSTATIC_RUNNING_REPO_ROOT}/${vSTATIC_REPO_SERVERS_DIR}"
  if [ ! -d "${servers_dir}/${vSTATIC_DEFAULT_SERVER}" ]; then
    log.error "The default server type does not exist at: ${servers_dir}/${vSTATIC_DEFAULT_SERVER}"
    exit 1
  fi
  #
  # Check that each server type has a .launch dir
  #
  for server in "${servers_dir}"/*; do
    if [ ! -d "$server" ]; then
      continue
    fi
    local server_name
    server_name=$(basename "$server")
    if [ ! -d "${servers_dir}/${server_name}/${vSTATIC_LAUNCH_DIRNAME}" ]; then
      log.error "The server type: ${server_name} does not have a launch dir at: ${servers_dir}/${server_name}/${vSTATIC_LAUNCH_DIRNAME}"
      exit 1
    fi
  done
}

cmd.precheck() {
  if [ "$vSTATIC_RUNNING_IN_GIT_REPO" == "true" ] && [ "$vSTATIC_HOST" == "local" ]; then
    subcmd.precheck.variables
    subcmd.precheck.launchfiles
  else
    log.error "this command can only be run from within a git repo."
    exit 1
  fi
}
