#!/usr/bin/env bash

daemon_loader__plugin_dir="${HOME}/.solos/plugins"
daemon_loader__src_plugins_dir="${HOME}/.solos/src/plugins"

daemon_loader.log_info() {
  local message="(LOADER) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_loader.log_error() {
  local message="(LOADER) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_loader.log_warn() {
  local message="(LOADER) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_warn "${message}" "$@"
}
daemon_loader.get_plugins() {
  local plugins=()
  while IFS= read -r plugin; do
    plugins+=("${daemon_loader__plugin_dir}/${plugin}")
  done < <(ls -1 "${daemon_loader__plugin_dir}")
  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "No plugins installed." >&2
    return 1
  fi
  echo "${daemon_loader__src_plugins_dir}/solos-precheck ${plugins[*]}"
}

daemon_loader.main() {
  local processed_file="${1}"
  local plugins="$(daemon_loader.get_plugins)"

  daemon_loader.log_info "Will do loading for plugins: ${plugins[@]}"
}
