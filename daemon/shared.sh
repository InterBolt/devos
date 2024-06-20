#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1

shared__pid=$$
shared__user_plugins_dir="/root/.solos/plugins"
shared__solos_plugins_dir="/root/.solos/src/plugins"
shared__precheck_plugin_path="${shared__solos_plugins_dir}/precheck/plugin"
shared__users_home_dir="$(lib.home_dir_path)"

shared.host_path() {
  local path="${1}"
  echo "${path/\/root\//${shared__users_home_dir}\/}"
}
shared.log_info() {
  local message="(DAEMON) ${1} pid=\"${shared__pid}\""
  shift
  log.info "${message}" "$@"
}
shared.log_error() {
  local message="(DAEMON) ${1} pid=\"${shared__pid}\""
  shift
  log.error "${message}" "$@"
}
shared.log_warn() {
  local message="(DAEMON) ${1} pid=\"${shared__pid}\""
  shift
  log.warn "${message}" "$@"
}
shared.get_solos_plugin_names() {
  local solos_plugin_names=($(ls -A1 "${shared__solos_plugins_dir}" | sed 's/^/solos-/g' | xargs))
  local plugins=()
  for solos_plugin_name in "${solos_plugin_names[@]}"; do
    if [[ ${solos_plugin_name} != "solos-precheck" ]]; then
      plugins+=("${solos_plugin_name}")
    fi
  done
  echo "${plugins[@]}" | xargs
}
shared.get_user_plugin_names() {
  local user_plugin_names=($(ls -A1 "${shared__user_plugins_dir}" | sed 's/^/user-/g' | xargs))
  echo "${user_plugin_names[@]}" | xargs
}
shared.get_precheck_plugin_names() {
  echo "precheck"
}
shared.plugin_paths_to_names() {
  local plugins=("${@}")
  local plugin_names=()
  for plugin in "${plugins[@]}"; do
    if [[ ${plugin} = "${shared__precheck_plugin_path}" ]]; then
      plugin_names+=("precheck")
    elif [[ ${plugin} =~ ^"${shared__user_plugins_dir}" ]]; then
      plugin_names+=("solos-$(basename "${plugin}")")
    else
      plugin_names+=("user-$(basename "${plugin}")")
    fi
  done
  echo "${plugin_names[*]}" | xargs
}
shared.plugin_names_to_paths() {
  local plugin_names=("${@}")
  local plugins=()
  for plugin_name in "${plugin_names[@]}"; do
    if [[ ${plugin_name} = "precheck" ]]; then
      plugins+=("${shared__precheck_plugin_path}")
    elif [[ ${plugin_name} =~ ^solos- ]]; then
      plugin_name="${plugin_name#solos-}"
      plugins+=("${shared__solos_plugins_dir}/${plugin_name}")
    elif [[ ${plugin_name} =~ ^user- ]]; then
      plugin_name="${plugin_name#user-}"
      plugins+=("${shared__user_plugins_dir}/${plugin_name}")
    fi
  done
  echo "${plugins[@]}"
}
