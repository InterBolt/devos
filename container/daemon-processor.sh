#!/usr/bin/env bash

daemon_processor__plugin_dir="${HOME}/.solos/plugins"
daemon_processor__src_plugins_dir="${HOME}/.solos/src/plugins"

daemon_processor.log_info() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_processor.log_error() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_processor.log_warn() {
  local message="(PROCESSOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log_warn "${message}" "$@"
}
daemon_processor.get_plugins() {
  local plugins=()
  while IFS= read -r plugin; do
    plugins+=("${daemon_processor__plugin_dir}/${plugin}")
  done < <(ls -1 "${daemon_processor__plugin_dir}")
  if [[ ${#plugins[@]} -eq 0 ]]; then
    echo "No plugins installed." >&2
    return 1
  fi
  echo "${daemon_processor__src_plugins_dir}/solos-precheck ${plugins[*]}"
}

daemon_processor.main() {
  local collections_dir="${1}"
  local plugins="$(daemon_processor.get_plugins)"

  daemon_processor.log_info "Will do processing for plugins: ${plugins[@]}"
}
