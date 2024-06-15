#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1

shared__pid=$$
shared__user_plugins_dir="/root/.solos/plugins"
shared__solos_plugins_dir="/root/.solos/src/plugins"
shared__precheck_plugin_path="${shared__user_plugins_dir}/precheck/plugin"
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
shared.merged_namespaced_fs() {
  local namespace="${1}"
  local partial_dir="${2}"
  local merged_dir="${3}"
  local partial_file="$(find "${partial_dir}" -type f | xargs)"
  for partial_file in ${partial_files}; do
    local partial_file_dir="$(dirname "${partial_file}")"
    local partial_file_name="$(basename "${partial_file}")"
    local merged_relative_path="${partial_file_dir#${partial_dir}}"
    local merged_abs_dirpath="${merged_dir}${merged_relative_path}"
    mkdir -p "${merged_abs_dirpath}"
    local merged_file_path="${merged_abs_dirpath}/${namespace}-${partial_file_name}"
    cp "${partial_file}" "${merged_file_path}"
  done
}
shared.validate_firejailed_assets() {
  local asset_firejailed_rel_path="${1}"
  local asset_host_path="${2}"
  local chmod_permission="${3}"
  if [[ -z "${asset_firejailed_rel_path}" ]]; then
    shared.log_error "Unexpected error - empty asset firejailed path."
    return 1
  fi
  if [[ "${asset_firejailed_rel_path}" =~ ^/ ]]; then
    shared.log_error "Unexpected error - asset firejailed path must not start with a \"/\""
    return 1
  fi
  if [[ ! "${chmod_permission}" =~ ^[0-7]{3}$ ]]; then
    shared.log_error "Unexpected error - invalid chmod permission."
    return 1
  fi
  if [[ ! -e ${asset_host_path} ]]; then
    shared.log_error "Unexpected error - invalid asset host path."
    return 1
  fi
}
shared.merge_assets_args() {
  local plugin_count="${1}"
  local plugin_index="${2}"
  local plugin_expanded_asset_args=($(echo "${3}" | xargs))
  local asset_args=($(echo "${4}" | xargs))
  local plugin_expanded_asset_arg_count="${#plugin_expanded_asset_args[@]}"
  plugin_expanded_asset_arg_count=$((plugin_expanded_asset_arg_count / 3))

  local grouped_plugin_expanded_asset_args=()
  local i=0
  for plugin_expanded_asset_arg in "${plugin_expanded_asset_args[@]}"; do
    if [[ $((i % 3)) -ne 0 ]]; then
      i=$((i + 1))
      continue
    fi
    local str=""
    str="${str} ${plugin_expanded_asset_args[${i}]}"
    str="${str} ${plugin_expanded_asset_args[$((i + 1))]}"
    str="${str} ${plugin_expanded_asset_args[$((i + 2))]}"
    grouped_plugin_expanded_asset_args+=("$(echo "${str}" | xargs)")
    i=$((i + 1))
  done
  local grouped_plugin_expanded_asset_args_count="${#grouped_plugin_expanded_asset_args[@]}"
  if [[ ${grouped_plugin_expanded_asset_args_count} -ne ${plugin_count} ]]; then
    shared.log_error "Unexpected error - the number of expanded assets does not match the number of plugins (warning, you'll need coffee and bravery for this one)."
    return 1
  fi
  echo "${asset_args[*]}" "${grouped_plugin_expanded_asset_args[${plugin_index}]}" | xargs
}
shared.firejail() {
  local phase_cache="${1}"
  local plugin_expanded_assets=($(echo "${2}" | xargs))
  local asset_args=($(echo "${3}" | xargs))
  local plugins=($(echo "${4}" | xargs))
  local firejail_options=($(echo "${5}" | xargs))
  local executable_options=($(echo "${6}" | xargs))
  local aggregated_stdout_file="${7}"
  local aggregated_stderr_file="${8}"
  local manifest_file="${9}"
  local firejailed_pids=()
  local firejailed_home_dirs=()
  local plugin_stdout_files=()
  local plugin_stderr_files=()
  local plugin_index=0
  local plugin_count="${#plugins[@]}"
  for plugin_path in "${plugins[@]}"; do
    if [[ ! -x ${plugin_path}/plugin ]]; then
      shared.log_error "Unexpected error - ${plugin_path}/plugin is not an executable file."
      return 1
    fi
    local plugins_dir="$(dirname "${plugin_path}")"
    local plugin_name="$(shared.plugin_paths_to_names "${plugins[${plugin_index}]}")"
    local plugin_phase_cache="${phase_cache}/${plugin_name}"
    mkdir -p "${plugin_phase_cache}"
    local merged_asset_args=($(shared.merge_assets_args "${plugin_count}" "${plugin_index}" "${plugin_expanded_asset_args[*]}" "${asset_args[*]}"))
    local merged_asset_arg_count="${#merged_asset_args[@]}"
    local firejailed_home_dir="$(mktemp -d)"
    local plugin_stdout_file="$(mktemp)"
    local plugin_stderr_file="$(mktemp)"
    for ((i = 0; i < ${merged_asset_arg_count}; i++)); do
      if [[ $((i % 3)) -ne 0 ]]; then
        continue
      fi
      local asset_firejailed_rel_path="${merged_asset_args[${i}]}"
      local asset_host_path="${merged_asset_args[$((i + 1))]}"
      local chmod_permission="${merged_asset_args[$((i + 2))]}"
      if ! shared.validate_firejailed_assets \
        "${asset_firejailed_rel_path}" \
        "${asset_host_path}" \
        "${chmod_permission}"; then
        return 1
      fi
      cp -r "${plugin_phase_cache}" "${firejailed_home_dir}/cache"
      local asset_firejailed_path="${firejailed_home_dir}/${asset_firejailed_rel_path}"
      if [[ -f ${asset_host_path} ]]; then
        cp "${asset_host_path}" "${asset_firejailed_path}"
      elif [[ -d ${asset_host_path} ]]; then
        mkdir -p "${asset_firejailed_path}"
        cp -r "${asset_host_path}" "${asset_firejailed_path}/"
      fi
      cp -a "${plugin_path}/plugin" "${firejailed_home_dir}/plugin"
      local plugin_config_file="${plugin_path}/solos.config.json"
      if [[ -f ${plugin_config_file} ]]; then
        cp "${plugin_config_file}" "${firejailed_home_dir}/solos.config.json"
      else
        echo "{}" >"${firejailed_home_dir}/solos.config.json"
      fi
      if [[ -f ${manifest_file} ]]; then
        cp "${manifest_file}" "${firejailed_home_dir}/solos.manifest.json"
      else
        return 1
      fi
      if [[ ! " ${executable_options[@]} " =~ " --phase-configure " ]]; then
        chmod 555 "${firejailed_home_dir}/solos.config.json"
      else
        chmod 777 "${firejailed_home_dir}/solos.config.json"
      fi
      chmod -R "${chmod_permission}" "${asset_firejailed_path}"
      firejail \
        --quiet \
        --noprofile \
        --private="${firejailed_home_dir}" \
        "${firejail_options[@]}" \
        /root/plugin "${executable_options[@]}" \
        >>"${plugin_stdout_file}" 2>>"${plugin_stderr_file}" &
      local firejailed_pid=$!
      firejailed_pids+=("${firejailed_pid}")
      firejailed_home_dirs+=("${firejailed_home_dir}")
      plugin_stdout_files+=("${plugin_stdout_file}")
      plugin_stderr_files+=("${plugin_stderr_file}")
    done
    plugin_index=$((plugin_index + 1))
  done

  local firejailed_kills=""
  local firejailed_failures=0
  local i=0
  for firejailed_pid in "${firejailed_pids[@]}"; do
    wait "${firejailed_pid}"
    local firejailed_exit_code=$?
    local executable_path="${plugins[${i}]}/plugin"
    local plugin_name="$(shared.plugin_paths_to_names "${plugins[${i}]}")"
    local firejailed_home_dir="${firejailed_home_dirs[${i}]}"
    # Blanket remove the restrictions placed on the firejailed files so that
    # our daemon can do what it needs to do with the files.
    chmod -R 777 "${firejailed_home_dir}"
    local plugin_stdout_file="${plugin_stdout_files[${i}]}"
    local plugin_stderr_file="${plugin_stderr_files[${i}]}"
    if [[ -f ${plugin_stdout_file} ]]; then
      while IFS= read -r line; do
        echo "(${plugin_name}) ${line}" >>"${aggregated_stderr_file}"
      done <"${plugin_stdout_file}"
    fi
    if [[ -f ${plugin_stderr_file} ]]; then
      while IFS= read -r line; do
        echo "(${plugin_name}) ${line}" >>"${aggregated_stdout_file}"
      done <"${plugin_stderr_file}"
    fi
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      echo "Firejailed plugin error - ${executable_path} exited with status ${firejailed_exit_code}" >&2
      firejailed_failures=$((firejailed_failures + 1))
    fi
    i=$((i + 1))
  done
  i=0
  for plugin_stdout_file in "${plugin_stdout_files[@]}"; do
    local plugin_name="$(shared.plugin_paths_to_names "${plugins[${i}]}")"
    if grep -q "^SOLOS_PANIC" "${plugin_stderr_file}" >/dev/null 2>/dev/null; then
      firejailed_kills="${firejailed_kills} ${plugin_name}"
    fi
    i=$((i + 1))
  done
  firejailed_kills=($(echo "${firejailed_kills}" | xargs))
  for plugin_stderr_file in "${plugin_stderr_files[@]}"; do
    if grep -q "^SOLOS_PANIC" "${plugin_stderr_file}" >/dev/null 2>/dev/null; then
      shared.log_warn "Invalid usage - the plugin sent a panic message to stdout." >&2
    fi
  done
  local return_code=0
  if [[ ${firejailed_failures} -gt 0 ]]; then
    shared.log_error "Unexpected plugin error - there were ${firejailed_failures} total failures across ${plugin_count} plugins."
    return_code=1
  fi
  if [[ ${#firejailed_kills[@]} -gt 0 ]]; then
    shared.log_warn "Unexpected plugin error - ${#firejailed_kills[@]} firejailed panic requests. Sources: ${firejailed_kills[*]}."
    return_code=151
  fi
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    echo "${firejailed_home_dir}"
  done
  return "${return_code}"
}
