#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

daemon_shared__pid=$$
daemon_shared__user_plugins_dir="/root/.solos/plugins"
daemon_shared__solos_plugins_dir="/root/.solos/src/plugins"
daemon_shared__precheck_plugin_path="${daemon_shared__user_plugins_dir}/precheck/plugin"
daemon_shared__users_home_dir="$(lib.home_dir_path)"

daemon_shared.host_path() {
  local path="${1}"
  echo "${path/\/root\//${daemon_shared__users_home_dir}\/}"
}
daemon_shared.log_info() {
  local message="(DAEMON) ${1} pid=\"${daemon_shared__pid}\""
  shift
  log.info "${message}" "$@"
}
daemon_shared.log_error() {
  local message="(DAEMON) ${1} pid=\"${daemon_shared__pid}\""
  shift
  log.error "${message}" "$@"
}
daemon_shared.log_warn() {
  local message="(DAEMON) ${1} pid=\"${daemon_shared__pid}\""
  shift
  log.warn "${message}" "$@"
}
daemon_shared.get_solos_plugin_names() {
  local solos_plugin_names=($(ls -A1 "${daemon_shared__solos_plugins_dir}" | sed 's/^/solos-/g' | xargs))
  local plugins=()
  for solos_plugin_name in "${solos_plugin_names[@]}"; do
    if [[ ${solos_plugin_name} != "solos-precheck" ]]; then
      plugins+=("${solos_plugin_name}")
    fi
  done
  echo "${plugins[@]}" | xargs
}
daemon_shared.get_user_plugin_names() {
  local user_plugin_names=($(ls -A1 "${daemon_shared__user_plugins_dir}" | sed 's/^/user-/g' | xargs))
  echo "${user_plugin_names[@]}" | xargs
}
daemon_shared.get_precheck_plugin_names() {
  echo "precheck"
}
daemon_shared.plugin_paths_to_names() {
  local plugins=("${@}")
  local plugin_names=()
  for plugin in "${plugins[@]}"; do
    if [[ ${plugin} = "${daemon_shared__precheck_plugin_path}" ]]; then
      plugin_names+=("precheck")
    elif [[ ${plugin} =~ ^"${daemon_shared__user_plugins_dir}" ]]; then
      plugin_names+=("solos-$(basename "${plugin}")")
    else
      plugin_names+=("user-$(basename "$(dirname "${plugin}")")")
    fi
  done
  echo "${plugin_names[*]}" | xargs
}
daemon_shared.plugin_names_to_paths() {
  local plugin_names=("${@}")
  local plugins=()
  for plugin_name in "${plugin_names[@]}"; do
    if [[ ${plugin_name} = "precheck" ]]; then
      plugins+=("${daemon_shared__precheck_plugin_path}")
    elif [[ ${plugin_name} =~ ^solos- ]]; then
      plugin_name="${plugin_name#solos-}"
      plugins+=("${daemon_shared__solos_plugins_dir}/${plugin_name}/plugin")
    elif [[ ${plugin_name} =~ ^user- ]]; then
      plugin_name="${plugin_name#user-}"
      plugins+=("${daemon_shared__user_plugins_dir}/${plugin_name}/plugin")
    fi
  done
  echo "${plugins[@]}"
}
daemon_shared.merged_namespaced_fs() {
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
daemon_shared.parse_firejail_args() {
  local seperators_count=0
  for arg in "${@}"; do
    if [[ ${arg} = "--" ]]; then
      seperators_count=$((seperators_count + 1))
    fi
  done
  local expects_seperators=5
  if [[ ${seperators_count} -ne ${expects_seperators} ]]; then
    daemon_shared.log_error "Unexpected error - expected ${expects_seperators} \"--\" seperators for each category of arguments and only found \"${seperators_count}\""
    return 1
  fi
  local plugin_expanded_assets=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    plugin_expanded_assets+=("${1}")
    shift
  done
  shift
  local assets=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    assets+=("${1}")
    shift
  done
  shift
  local plugins=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    plugins+=("${1}")
    shift
  done
  shift
  local firejail_options=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    firejail_options+=("${1}")
    shift
  done
  shift
  local executable_options=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    executable_options+=("${1}")
    shift
  done
  shift
  local stdout_dump_file="${1}"
  local stderr_dump_file="${2}"
  if [[ ! -f ${stdout_dump_file} ]]; then
    daemon_shared.log_error "Unexpected error - no stdout file was provided to the shared firejail function"
    return 1
  fi
  if [[ ! -f ${stderr_dump_file} ]]; then
    daemon_shared.log_error "Unexpected error - no stderr file was provided to the shared firejail function"
    return 1
  fi
  echo "${plugin_expanded_assets[*]}"
  echo "${assets[*]}"
  echo "${plugins[*]}"
  echo "${firejail_options[*]}"
  echo "${executable_options[*]}"
  echo "${stdout_dump_file}"
  echo "${stderr_dump_file}"
}
daemon_shared.validate_firejailed_assets() {
  local asset_firejailed_rel_path="${1}"
  local asset_host_path="${2}"
  local chmod_permission="${3}"
  if [[ -z "${asset_firejailed_rel_path}" ]]; then
    daemon_shared.log_error "Unexpected error - empty asset firejailed path."
    return 1
  fi
  if [[ "${asset_firejailed_rel_path}" =~ ^/ ]]; then
    daemon_shared.log_error "Unexpected error - asset firejailed path must not start with a \"/\""
    return 1
  fi
  if [[ ! "${chmod_permission}" =~ ^[0-7]{3}$ ]]; then
    daemon_shared.log_error "Unexpected error - invalid chmod permission."
    return 1
  fi
  if [[ ! -e ${asset_host_path} ]]; then
    daemon_shared.log_error "Unexpected error - invalid asset host path."
    return 1
  fi
}
daemon_shared.encode_dumped_output() {
  local plugin_name="${1}"
  local stderr_file="${2}"
  local stdout_file="${3}"
  local stderr_dump_file="${4}"
  local stdout_dump_file="${5}"
  if [[ -f ${stderr_file} ]]; then
    while IFS= read -r line; do
      echo "DUMP-${plugin_name}: ${line}" >>"${stderr_dump_file}"
    done <"${stderr_file}"
  fi
  if [[ -f ${stdout_file} ]]; then
    while IFS= read -r line; do
      echo "DUMP-${plugin_name}: ${line}" >>"${stdout_dump_file}"
    done <"${stdout_file}"
  fi
}
daemon_shared.decode_dumped_output() {
  local plugin_name="${1}"
  local input_stdout_file="${2}"
  local input_stderr_file="${3}"
  local output_stdout_file="${4}"
  local output_stderr_file="${5}"
  while IFS= read -r line; do
    if [[ ${line} =~ ^DUMP-${plugin_name}: ]]; then
      line="${line//DUMP-${plugin_name}: /}"
      echo "(${plugin_name}) ${line}" >>"${output_stderr_file}"
    fi
  done <"${input_stderr_file}"
  while IFS= read -r line; do
    if [[ ${line} =~ ^DUMP-${plugin_name}: ]]; then
      line="${line//DUMP-${plugin_name}: /}"
      echo "(${plugin_name}) ${line}" >>"${output_stdout_file}"
    fi
  done <"${input_stdout_file}"
}
daemon_shared.merge_assets_args() {
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
    daemon_shared.log_error "Unexpected error - the number of expanded assets does not match the number of plugins (warning, you'll need coffee and bravery for this one)."
    return 1
  fi
  echo "${asset_args[*]}" "${grouped_plugin_expanded_asset_args[${plugin_index}]}" | xargs
}
daemon_shared.firejail() {
  local args="$(daemon_shared.parse_firejail_args "${@}")"
  local plugin_expanded_asset_args=($(lib.line_to_args "${args}" "0"))
  local asset_args=($(lib.line_to_args "${args}" "1"))
  local plugins=($(lib.line_to_args "${args}" "2"))
  local firejail_options=($(lib.line_to_args "${args}" "3"))
  local executable_options=($(lib.line_to_args "${args}" "4"))
  local stdout_dump_file="$(lib.line_to_args "${args}" "5")"
  local stderr_dump_file="$(lib.line_to_args "${args}" "6")"
  local firejailed_pids=()
  local firejailed_home_dirs=()
  local firejailed_raw_stdout_files=()
  local firejailed_raw_stderr_files=()
  local plugin_index=0
  local plugin_count="${#plugins[@]}"
  for plugin in "${plugins[@]}"; do
    if [[ ! -x ${plugin} ]]; then
      daemon_shared.log_error "Unexpected error - ${plugin} is not an executable file."
      return 1
    fi
    local merged_asset_args=($(daemon_shared.merge_assets_args "${plugin_count}" "${plugin_index}" "${plugin_expanded_asset_args[*]}" "${asset_args[*]}"))
    local merged_asset_arg_count="${#merged_asset_args[@]}"
    local firejailed_home_dir="$(mktemp -d)"
    local firejailed_raw_stdout_file="$(mktemp)"
    local firejailed_raw_stderr_file="$(mktemp)"
    for ((i = 0; i < ${merged_asset_arg_count}; i++)); do
      if [[ $((i % 3)) -ne 0 ]]; then
        continue
      fi
      local asset_firejailed_rel_path="${merged_asset_args[${i}]}"
      local asset_host_path="${merged_asset_args[$((i + 1))]}"
      local chmod_permission="${merged_asset_args[$((i + 2))]}"
      if ! daemon_shared.validate_firejailed_assets \
        "${asset_firejailed_rel_path}" \
        "${asset_host_path}" \
        "${chmod_permission}"; then
        return 1
      fi
      local asset_firejailed_path="${firejailed_home_dir}/${asset_firejailed_rel_path}"
      if [[ -f ${asset_host_path} ]]; then
        cp "${asset_host_path}" "${asset_firejailed_path}"
      elif [[ -d ${asset_host_path} ]]; then
        mkdir -p "${asset_firejailed_path}"
        cp -r "${asset_host_path}" "${asset_firejailed_path}/"
      fi
      cp -a "${plugin}" "${firejailed_home_dir}/plugin"
      local plugin_config_file="${plugin}/solos.json"
      if [[ -f ${plugin_config_file} ]]; then
        cp "${plugin_config_file}" "${firejailed_home_dir}/solos.json"
      fi
      if [[ ! " ${executable_options[@]} " =~ " --phase-configure " ]]; then
        chmod 444 "${firejailed_home_dir}/solos.json"
      fi
      chmod -R "${chmod_permission}" "${asset_firejailed_path}"
      firejail \
        --quiet \
        --noprofile \
        --private="${firejailed_home_dir}" \
        "${firejail_options[@]}" \
        /root/plugin "${executable_options[@]}" \
        >>"${firejailed_raw_stdout_file}" 2>>"${firejailed_raw_stderr_file}" &
      local firejailed_pid=$!
      firejailed_pids+=("${firejailed_pid}")
      firejailed_home_dirs+=("${firejailed_home_dir}")
      firejailed_raw_stdout_files+=("${firejailed_raw_stdout_file}")
      firejailed_raw_stderr_files+=("${firejailed_raw_stderr_file}")
    done
    plugin_index=$((plugin_index + 1))
  done

  local firejailed_requesting_kill=false
  local firejailed_failures=0
  local i=0
  for firejailed_pid in "${firejailed_pids[@]}"; do
    wait "${firejailed_pid}"
    local firejailed_exit_code=$?
    local executable_path="${plugins[${i}]}"
    local plugin_name="$(daemon_shared.plugin_paths_to_names "${plugins[${i}]}")"
    local firejailed_home_dir="${firejailed_home_dirs[${i}]}"
    # Blanket remove the restrictions placed on the firejailed files so that
    # our daemon can do what it needs to do with the files.
    chmod -R 777 "${firejailed_home_dir}"
    local firejailed_raw_stdout_file="${firejailed_raw_stdout_files[${i}]}"
    local firejailed_raw_stderr_file="${firejailed_raw_stderr_files[${i}]}"
    daemon_shared.encode_dumped_output \
      "${plugin_name}" \
      "${firejailed_raw_stderr_file}" \
      "${firejailed_raw_stdout_file}" \
      "${stderr_dump_file}" \
      "${stdout_dump_file}"
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      echo "Firejailed plugin error - ${executable_path} exited with status ${firejailed_exit_code}" >&2
      firejailed_failures=$((firejailed_failures + 1))
    fi
    i=$((i + 1))
  done
  if grep -q "^SOLOS_PANIC" "${firejailed_raw_stderr_file}" >/dev/null 2>/dev/null; then
    firejailed_requesting_kill=true
  fi
  if grep -q "^SOLOS_PANIC" "${firejailed_raw_stdout_file}" >/dev/null 2>/dev/null; then
    daemon_shared.log_warn "Invalid usage - the plugin sent a panic message to stdout." >&2
  fi
  local return_code=0
  if [[ ${firejailed_failures} -gt 0 ]]; then
    daemon_shared.log_error "Unexpected plugin error - there were ${firejailed_failures} malfunctions across all plugins."
    return_code=1
  fi
  if [[ ${firejailed_requesting_kill} = true ]]; then
    daemon_shared.log_error "Unexpected plugin error - a collection made a kill request in it's output."
    return_code=151
  fi
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    echo "${firejailed_home_dir}"
  done
  return "${return_code}"
}
