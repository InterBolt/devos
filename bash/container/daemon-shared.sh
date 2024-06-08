#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

daemon_shared__installed_plugins_dir="${HOME}/.solos/installed"
daemon_shared__precheck_plugin="${HOME}/.solos/src/plugins/solos-precheck"

if [[ ! -d "${daemon_shared__precheck_plugin}" ]]; then
  lib.panics_add "missing_precheck_plugin" <<EOF
The "precheck" plugin was not found at ${daemon_shared__precheck_plugin}. \
This plugin is NOT something that needs to be installed by the user. It should always \
run as part of the daemon that executes the plugins.
EOF
  exit 1
fi

daemon_shared.get_plugins() {
  local plugins=()
  while IFS= read -r plugin; do
    plugins+=("${daemon_shared__installed_plugins_dir}/${plugin}")
  done < <(ls -1 "${daemon_shared__installed_plugins_dir}")
  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "No plugins installed." >&2
    return 1
  fi
  echo "${daemon_shared__precheck_plugin} ${plugins[*]}"
}
