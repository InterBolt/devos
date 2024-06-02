#!/usr/bin/env bash

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1

__profile_plugins__fn__cli() {
  if [[ ${1} == "--help" ]]; then
    __profile_plugins__fn__cli_usage
    return 0
  fi
  local subcommand="${1}"
  shift
  if ! declare -F "__profile_plugins__fn__cli_${subcommand}" >/dev/null; then
    log_error "Unsupported command: ${subcommand}. See \`plugin --help\` for available commands."
    return 1
  fi
  if [[ ${1} == "--help" ]]; then
    "__profile_plugins__fn__cli_usage_${subcommand}"
    return 0
  fi
  "__profile_plugins__fn__cli_${subcommand}" "$@"
}
__profile_plugins__fn__cli_usage() {
  cat <<EOF
USAGE: plugin <install|uninstall|list> [...args]

DESCRIPTION:

Manage SolOS plugins.

EOF
}
__profile_plugins__fn__cli_usage_install() {
  cat <<EOF
USAGE: plugin install <name> --loader <loader> --collector <collector> --processor <processor> --config <config>

DESCRIPTION:

Install a SolOS plugin by providing the urls to the required executables.

EOF
}
__profile_plugins__fn__cli_usage_list() {
  cat <<EOF
USAGE: plugin list

DESCRIPTION:

List all installed SolOS plugins.

EOF
}
__profile_plugins__fn__cli_usage_uninstall() {
  cat <<EOF
USAGE: plugin uninstall <name>

DESCRIPTION:

Uninstall a SolOS plugin. 

EOF
}
__profile_plugins__fn__cli_install() {
  local loader=""
  local collector=""
  local processor=""
  local config=""
  while [[ $# -gt 0 ]]; do
    case "${1}" in
    --loader)
      loader="${2}"
      shift 2
      ;;
    --collector)
      collector="${2}"
      shift 2
      ;;
    --processor)
      processor="${2}"
      shift 2
      ;;
    --config)
      config="${2}"
      shift 2
      ;;
    *)
      log_error "Unknown option: ${1}"
      return 1
      ;;
    esac
  done
  if [[ -z ${loader} ]]; then
    log_error "Missing required option: --loader"
    return 1
  fi
  if [[ -z ${collector} ]]; then
    log_error "Missing required option: --collector"
    return 1
  fi
  if [[ -z ${processor} ]]; then
    log_error "Missing required option: --processor"
    return 1
  fi
  if [[ -z ${config} ]]; then
    log_error "Missing required option: --config"
    return 1
  fi
  local plugin_name="${1}"
  local plugins_dir="${HOME}/.solos/plugins"
  local plugin_dir="${plugins_dir}/${plugin_name}"
  if [[ -d ${plugin_dir} ]]; then
    log_error "Plugin \`${plugin_name}\` already exists. Please uninstall it first or use a different name for the new plugin."
    return 1
  fi
  local tmp_dir="$(mktemp -d)"
  curl "${loader}" -o "${tmp_dir}/loader.exe" -s &
  curl "${collector}" -o "${tmp_dir}/collector.exe" -s &
  curl "${processor}" -o "${tmp_dir}/processor.exe" -s &
  curl "${config}" -o "${tmp_dir}/config.json" -s &
  wait
  if [[ ! -f ${tmp_dir}/loader.exe ]]; then
    log_error "Failed to download loader from ${loader}"
    return 1
  fi
  if [[ ! -f ${tmp_dir}/collector.exe ]]; then
    log_error "Failed to download collector from ${collector}"
    return 1
  fi
  if [[ ! -f ${tmp_dir}/processor.exe ]]; then
    log_error "Failed to download processor from ${processor}"
    return 1
  fi
  if [[ ! -f ${tmp_dir}/config.json ]]; then
    log_error "Failed to download config from ${config}"
    return 1
  fi
  if ! jq . "${tmp_dir}/config.json" >/dev/null 2>&1; then
    log_error "Invalid config file. JSON parsing failed."
    return 1
  fi
  jq '. + { "sources": { "loader": "'${loader}'", "collector": "'${collector}'", "processor": "'${processor}'", "config": "'${config}'" } }' "${tmp_dir}/config.json" >"${plugin_dir}/config.json"
  local required_keys=()
  local i=0
  while IFS= read -r key; do
    if [[ ${key} == "requires" ]]; then
      continue
    fi
    if [[ $(jq -r ".${key}" "${tmp_dir}/config.json") = null ]]; then
      echo "Missing required key: ${key}"
      return 1
    fi
    required_keys+=("${key}")
    i=$((i + 1))
  done < <(jq -r ".requires[]" "${tmp_dir}/config.json")
  for key in "${required_keys[@]}"; do
    local next_value="$(gum_plugin_config_input "${key}")"
    if [[ ${next_value} = "SOLOS:EXIT:1" ]]; then
      return 1
    fi
    values+=("${next_value}")
  done
  i=0
  for key in "${required_keys[@]}"; do
    jq '. + { "'${key}'": "'${values[i]}'" }' "${tmp_dir}/config.json" >"${tmp_dir}/config.json.tmp"
    mv "${tmp_dir}/config.json.tmp" "${tmp_dir}/config.json"
    i=$((i + 1))
  done
  chmod +x "${tmp_dir}/loader.exe" "${tmp_dir}/collector.exe" "${tmp_dir}/processor.exe"
  mv "${tmp_dir}" "${plugin_dir}"
  log_info "Plugin \`${plugin_name}\` installed."
}
__profile_plugins__fn__cli_list() {
  local plugins_dir="${HOME}/.solos/plugins"
  mkdir -p "${plugins_dir}"
  local plugins=()
  while IFS= read -r plugin; do
    plugins+=("${plugin}")
  done < <(ls -1 "${plugins_dir}")
  if [[ ${#plugins[@]} -eq 0 ]]; then
    log_info "No plugins installed."
    return 0
  fi
  for plugin in "${plugins[@]}"; do
    printf "\033[0;34m%s\033[0m\n" "${plugin}"
  done
}
__profile_plugins__fn__cli_uninstall() {
  local plugin_name="${1}"
  local plugins_dir="${HOME}/.solos/plugins"
  local plugin_dir="${plugins_dir}/${plugin_name}"
  if [[ -d ${plugin_dir} ]]; then
    rm -rf "${plugin_dir}"
    log_info "Plugin \`${plugin_name}\` uninstalled."
  else
    log_error "Plugin \`${plugin_name}\` not found."
  fi
}