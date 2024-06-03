#!/usr/bin/env bash

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1

profile_plugins__data_dir="${HOME}/.solos/data/plugins"
profile_plugins__dir="${HOME}/.solos/plugins"

profile_plugins.init_fs() {
  mkdir -p "${profile_plugins__data_dir}"
  mkdir -p "${profile_plugins__dir}"
  if [[ ! -f ${profile_plugins__data_dir}/processed.log ]]; then
    touch "${profile_plugins__data_dir}/processed.log"
  fi
  if [[ ! -f ${profile_plugins__data_dir}/collected.log ]]; then
    touch "${profile_plugins__data_dir}/collected.log"
  fi
}
profile_plugins.cli_usage() {
  cat <<EOF
USAGE: plugin <install|uninstall|list> [...args]

DESCRIPTION:

Manage SolOS plugins.

EOF
}
profile_plugins.cli_usage_install() {
  cat <<EOF
USAGE: plugin install <name> --loader=<loader> --collector=<collector> --processor=<processor> --config=<config>

DESCRIPTION:

Install a SolOS plugin by providing the urls to the required executables.

EOF
}
profile_plugins.cli_usage_list() {
  cat <<EOF
USAGE: plugin list

DESCRIPTION:

List all installed SolOS plugins.

EOF
}
profile_plugins.cli_usage_uninstall() {
  cat <<EOF
USAGE: plugin uninstall <name>

DESCRIPTION:

Uninstall a SolOS plugin. 

EOF
}
profile_plugins.cli_install() {
  local plugin_name="${1}"
  shift
  local loader=""
  local collector=""
  local processor=""
  local config=""
  for arg in "$@"; do
    case "${arg}" in
    --loader=*)
      loader="${arg#*=}"
      ;;
    --collector=*)
      collector="${arg#*=}"
      ;;
    --processor=*)
      processor="${arg#*=}"
      ;;
    --config=*)
      config="${arg#*=}"
      ;;
    *)
      log_error "Invalid option: ${arg}"
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
  local plugin_dir="${profile_plugins__dir}/${plugin_name}"
  if [[ -d ${plugin_dir} ]]; then
    log_error "Plugin \`${plugin_name}\` already exists. Please uninstall it first or use a different name for the new plugin."
    return 1
  fi
  local tmp_dir="$(mktemp -d)"
  log_info "Downloading plugin executables..."
  curl "${loader}" -o "${tmp_dir}/loader.exe" -s &
  curl "${collector}" -o "${tmp_dir}/collector.exe" -s &
  curl "${processor}" -o "${tmp_dir}/processor.exe" -s &
  curl "${config}" -o "${tmp_dir}/config.json" -s &
  wait
  log_info "Downloaded executables from their remove sources \`${plugin_name}\`."
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
  jq '. + { "sources": { "loader": "'"${loader}"'", "collector": "'"${collector}"'", "processor": "'"${processor}"'", "config": "'"${config}"'" } }' "${tmp_dir}/config.json" >"${tmp_dir}/config.json.tmp"
  mv "${tmp_dir}/config.json.tmp" "${tmp_dir}/config.json"
  local required_keys=()
  local i=0
  while IFS= read -r key; do
    if [[ ${key} = "requires" ]]; then
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
profile_plugins.cli_list() {
  local plugins=()
  while IFS= read -r plugin; do
    plugins+=("${plugin}")
  done < <(ls -1 "${profile_plugins__dir}")
  if [[ ${#plugins[@]} -eq 0 ]]; then
    log_info "No plugins installed."
    return 0
  fi
  local print_args=()
  for plugin in "${plugins[@]}"; do
    print_args=("${plugin}" "${profile_plugins__dir}/${plugin}/config.json")
  done
  cat <<EOF
$(
    profile_table_outputs.format \
      "INSTALLED_PLUGIN,CONFIG_PATH" \
      "${print_args[@]}"
  )
EOF
}
profile_plugins.cli_uninstall() {
  local plugin_name="${1}"
  if [[ -z ${plugin_name} ]]; then
    log_error "Missing required argument: <name>"
    return 1
  fi
  local plugin_dir="${profile_plugins__dir}/${plugin_name}"
  if [[ -d ${plugin_dir} ]]; then
    rm -rf "${plugin_dir}"
    log_info "Plugin \`${plugin_name}\` uninstalled."
  else
    log_error "Plugin \`${plugin_name}\` not found."
  fi
}
profile_plugins.main() {
  if ! profile_plugins.init_fs; then
    log_error "Failed to initialize plugin filesystem."
    return 1
  fi
  local cmd="${1}"
  if profile.is_help_cmd "${1}"; then
    profile_plugins.cli_usage
    return 0
  fi
  if [[ -z ${cmd} ]]; then
    log_error "Missing required argument: <command>"
    return 1
  fi
  shift
  local cmd_arg="${1}"
  if ! declare -F "profile_plugins.cli_${cmd}" >/dev/null; then
    log_error "Unsupported command: ${cmd}. See \`plugin --help\` for available commands."
    return 1
  fi
  if profile.is_help_cmd "${cmd_arg}"; then
    "profile_plugins.cli_usage_${cmd}"
    return 0
  fi
  "profile_plugins.cli_${cmd}" "$@"
}
