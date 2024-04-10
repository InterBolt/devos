#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=solos.sh
. "__shared__/static.sh"
# shellcheck source=solos.utils.sh
. "__shared__/static.sh"
# shellcheck source=__shared__/static.sh
. "__shared__/static.sh"

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
  # Check that all the variables we use in our bootfile templates are defined
  # in solos' global variables.
  #
  utils.template_variables "${vSTATIC_REPO_TEMPLATES_DIR}" "dry" "allow_empty"
  cd "$entry_pwd"
  log.info "test passed: launchfiles are valid and match global variables."
  #
  # Check that the defualt server type exists
  #
  if [ ! -d "$vSTATIC_RUNNING_REPO_ROOT/$vSTATIC_REPO_SERVERS_DIR/$vSTATIC_DEFAULT_SERVER" ]; then
    log.error "The default server type does not exist at: $vSTATIC_RUNNING_REPO_ROOT/$vSTATIC_REPO_SERVERS_DIR/$vSTATIC_DEFAULT_SERVER"
    exit 1
  fi
}

precheck.all() {
  precheck.variables
  precheck.launchfiles
}