#!/usr/bin/env bash

daemon_collector__plugin_dir="${HOME}/.solos/plugins"
daemon_collector__src_plugins_dir="${HOME}/.solos/src/plugins"

daemon_collector.log_info() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_collector.log_error() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_collector.log_warn() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_warn "${message}" "$@"
}
daemon_collector.get_plugins() {
  local plugins=()
  while IFS= read -r plugin; do
    plugins+=("${daemon_collector__plugin_dir}/${plugin}")
  done < <(ls -1 "${daemon_collector__plugin_dir}")
  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "No plugins installed." >&2
    return 1
  fi
  echo "${daemon_collector__src_plugins_dir}/solos-precheck ${plugins[*]}"
}

daemon_collector.main() {
  local scrubbed_copy="${1}"
  local collections_dir="${2}"
  local plugins="$(daemon_collector.get_plugins)"

  daemon_collector.log_info "Will do collections for plugins: ${plugins[@]}"
}
