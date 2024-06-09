#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

daemon_shared__internal_plugins_dir="${HOME}/.solos/src/plugins"
daemon_shared__installed_plugins_dir="${HOME}/.solos/installed"
daemon_shared__precheck_plugin="${daemon_shared__internal_plugins_dir}/precheck"

# TODO: go back and refactor some things to use this new idea of having every script
# TODO[c]: implement a __LIB_PREFIX.panic_conditions__ that gets called immediately when sourced.
__daemon_shared.panic_conditions__() {
  local panicked=false
  if [[ ! -d ${daemon_shared__precheck_plugin} ]]; then
    lib.panics_add "missing_precheck_plugin" <<EOF
The "precheck" plugin was not found at ${daemon_shared__precheck_plugin}. \
This plugin is NOT something that needs to be installed by the user. It should always \
run as part of the daemon that executes the plugins.
EOF
    panicked=true
  fi
  if [[ ! -d ${daemon_shared__internal_plugins_dir} ]]; then
    lib.panics_add "missing_internal_plugins" <<EOF
The "precheck" plugin was not found at ${daemon_shared__precheck_plugin}. \
This plugin is NOT something that needs to be installed by the user. It should always \
run as part of the daemon that executes the plugins.
EOF
    panicked=true
  fi
  if [[ ${panicked} = true ]]; then
    log.error "Panic condition detected. Review panic files. Exiting."
    exit 1
  fi
}

# SHARED/SOURCED FUNCTIONS:

daemon_shared.get_internal_plugins() {
  local installed_plugins=()
  while IFS= read -r installed_plugin; do
    installed_plugins+=("${daemon_shared__installed_plugins_dir}/${installed_plugin}")
  done < <(ls -1 "${daemon_shared__installed_plugins_dir}")
  if [[ ${#installed_plugins[@]} -eq 0 ]]; then
    echo ""
    return 0
  fi
  echo "${installed_plugins[*]}"
}
daemon_shared.get_installed_plugins() {
  local internal_plugins=()
  while IFS= read -r internal_plugin; do
    internal_plugins+=("${daemon_shared__internal_plugins_dir}/${internal_plugin}")
  done < <(ls -1 "${daemon_shared__internal_plugins_dir}")
  if [[ ${#internal_plugins[@]} -eq 0 ]]; then
    echo ""
    return 0
  fi
  echo "${internal_plugins[*]}"
}
daemon_shared.get_precheck_plugins() {
  echo "${daemon_shared__precheck_plugin}"
}

__daemon_shared.panic_conditions__
