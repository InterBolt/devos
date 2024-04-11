#!/usr/bin/env bash
# shellcheck disable=SC2103,SC2164
set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd ..
fi
if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=../solos.sh
. shared/empty.sh
# shellcheck source=../solos.utils.sh
. solos.utils.sh
# shellcheck source=../shared/static.sh
. shared/static.sh
# shellcheck source=../shared/log.sh
. shared/log.sh

log.ready "cmd_precheck" "${vSTATIC_RUNNING_REPO_ROOT}/${vSTATIC_LOGS_DIRNAME}"

precheck.variables() {
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
    local global_vars=$(utils.grep_global_vars "$file")
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

precheck.launchfiles() {
  local entry_pwd="$PWD"
  cd "${vSTATIC_RUNNING_REPO_ROOT}"
  #
  # Check that all the variables we use in the bin's .launch dir are defined
  # in solos' global variables.
  #
  utils.template_variables "${vSTATIC_BIN_LAUNCH_DIR}" "dry" "allow_empty"
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

precheck.run() {
  precheck.variables
  precheck.launchfiles
}

precheck.run
