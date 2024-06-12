#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

daemon_shared__user_plugins_dir="/root/.solos/plugins"
daemon_shared__solos_plugins_dir="/root/.solos/src/plugins"
daemon_shared__precheck_plugin_path="${daemon_shared__user_plugins_dir}/precheck/plugin"

# SHARED/SOURCED FUNCTIONS:
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
    # The result is if the plugin created a file sandboxed/foo/bar.txt, it will be moved to
    # merged/sandboxed/foo/internal-plugin-name-bar.txt (or whatever the namespace is)
    mv "${partial_file}" "${merged_file_path}"
  done
}
daemon_shared.parse_firejail_args() {
  local seperators_count=0
  for arg in "${@}"; do
    if [[ ${arg} = "--" ]]; then
      seperators_count=$((seperators_count + 1))
    fi
  done
  local expects_seperators=4
  if [[ ${seperators_count} -ne ${expects_seperators} ]]; then
    echo "Unexpected error - expected ${expects_seperators} \"--\" seperators for each category of arguments and only found \"${seperators_count}\"" >&2
    return 1
  fi
  local assets=()
  local asset_args_count=0
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    asset_args_count=$((asset_args_count + 1))
    assets+=("${1}")
    shift
  done
  if [[ $((asset_args_count % 3)) -ne 0 ]]; then
    echo "Unexpected error - expected the first set of asset arguments to come in threes but instead got ${asset_args_count}." >&2
    return 1
  fi
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
    echo "Unexpected error - no stdout file was provided to the shared firejail function" >&2
    return 1
  fi
  if [[ ! -f ${stderr_dump_file} ]]; then
    echo "Unexpected error - no stderr file was provided to the shared firejail function" >&2
    return 1
  fi
  local asset_count=$((asset_count / 3))
  echo "${assets[@]}"
  echo "${plugins[@]}"
  echo "${firejail_options[@]}"
  echo "${executable_options[@]}"
  echo "${stdout_dump_file}"
  echo "${stderr_dump_file}"
}
daemon_shared.validate_firejailed_assets() {
  local asset_firejailed_rel_path="${1}"
  local asset_host_path="${2}"
  local chmod_permission="${3}"
  if [[ -z "${asset_firejailed_rel_path}" ]]; then
    echo "Unexpected error - empty asset firejailed path." >&2
    return 1
  fi
  if [[ "${asset_firejailed_rel_path}" =~ ^/ ]]; then
    echo "Unexpected error - asset firejailed path must not start with a \"/\"" >&2
    return 1
  fi
  if [[ ! "${chmod_permission}" =~ ^[0-7]{3}$ ]]; then
    echo "Unexpected error - invalid chmod permission." >&2
    return 1
  fi
  if [[ ! -e ${asset_host_path} ]]; then
    echo "Unexpected error - invalid asset host path." >&2
    return 1
  fi
}
daemon_shared.encode_dumped_output() {
  local stderr_file="${1}"
  local stdout_file="${2}"
  local stderr_dump_file="${3}"
  local stdout_dump_file="${4}"
  if [[ -f ${stderr_file} ]]; then
    while IFS= read -r line; do
      echo "DUMP-${i}: ${line}" >>"${stderr_dump_file}"
    done <"${stderr_file}"
  fi
  if [[ -f ${stdout_file} ]]; then
    while IFS= read -r line; do
      echo "DUMP-${i}: ${line}" >>"${stdout_dump_file}"
    done <"${stdout_file}"
  fi
}
daemon_shared.decode_dumped_output() {
  local prefix="${1}"
  local input_stdout_file="${2}"
  local input_stderr_file="${3}"
  local output_stdout_file="${4}"
  local output_stderr_file="${5}"
  while IFS= read -r line; do
    if [[ ${line} =~ ^DUMP-${i}: ]]; then
      line="${line//DUMP-${i}: /}"
      echo "${prefix} ${line}" >>"${output_stderr_file}"
    fi
  done <"${input_stderr_file}"
  while IFS= read -r line; do
    if [[ ${line} =~ ^DUMP-${i}: ]]; then
      line="${line//DUMP-${i}: /}"
      echo "${prefix} ${line}" >>"${output_stdout_file}"
    fi
  done <"${input_stdout_file}"
}
daemon_shared.firejail() {
  local parsed_args="$(daemon_shared.parse_firejail_args "${@}")"
  local assets=($(lib.line_to_args "${args}" "0"))
  local plugins=($(lib.line_to_args "${args}" "1"))
  local firejail_options=($(lib.line_to_args "${args}" "2"))
  local executable_options=($(lib.line_to_args "${args}" "3"))
  local stdout_dump_file="$(lib.line_to_args "${args}" "4")"
  local stderr_dump_file="$(lib.line_to_args "${args}" "5")"

  local asset_arg_count="${#assets[@]}"
  local asset_count=$((asset_arg_count / 3))
  local firejailed_pids=()
  local firejailed_home_dirs=()
  local firejailed_raw_stdout_files=()
  local firejailed_raw_stderr_files=()
  for plugin in "${plugins[@]}"; do
    if [[ ! -x ${plugin} ]]; then
      echo "Unexpected error - ${plugin} is not an executable file." >&2
      return 1
    fi
    local firejailed_home_dir="$(mktemp -d)"
    local firejailed_raw_stdout_file="$(mktemp)"
    local firejailed_raw_stderr_file="$(mktemp)"
    for ((i = 0; i < ${asset_count}; i++)); do
      if [[ $((i % 3)) -ne 0 ]]; then
        continue
      fi
      if [[ -z "${assets[${i}]}" ]]; then
        echo "Unexpected error - empty asset firejailed path." >&2
        return 1
      fi
      local asset_firejailed_rel_path="${assets[${i}]}"
      local asset_host_path="${assets[$((i + 1))]}"
      local chmod_permission="${assets[$((i + 2))]}"
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
  done

  local firejailed_requesting_kill=false
  local firejailed_failures=0
  local successful_home_dirs=()
  local i=0
  for firejailed_pid in "${firejailed_pids[@]}"; do
    wait "${firejailed_pid}"
    local firejailed_exit_code=$?
    local executable_path="${plugins[${i}]}"
    local firejailed_home_dir="${firejailed_home_dirs[${i}]}"
    # Blanket remove the restrictions placed on the firejailed files.
    chmod -R 777 "${firejailed_home_dir}"
    local firejailed_raw_stdout_file="${firejailed_raw_stdout_files[${i}]}"
    local firejailed_raw_stderr_file="${firejailed_raw_stderr_files[${i}]}"
    daemon_shared.encode_dumped_output \
      "${firejailed_raw_stderr_file}" \
      "${firejailed_raw_stdout_file}" \
      "${stderr_dump_file}" \
      "${stdout_dump_file}"
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      echo "Firejailed plugin error - ${executable_path} exited with status ${firejailed_exit_code}" >&2
      firejailed_failures=$((firejailed_failures + 1))
      successful_home_dirs+=("-")
    else
      successful_home_dirs+=("${firejailed_home_dir}")
    fi
    i=$((i + 1))
  done
  if grep -q "^SOLOS_PANIC" "${firejailed_raw_stderr_file}" >/dev/null 2>/dev/null; then
    firejailed_requesting_kill=true
  fi
  if grep -q "^SOLOS_PANIC" "${firejailed_raw_stdout_file}" >/dev/null 2>/dev/null; then
    echo "Invalid usage - the plugin sent a panic message to stdout." >&2
  fi
  local return_code=0
  if [[ ${firejailed_failures} -gt 0 ]]; then
    echo "Firejailed plugin error - there were ${firejailed_failures} plugin malfunctions." >&2
    return_code=1
  fi
  if [[ ${firejailed_requesting_kill} = true ]]; then
    echo "Firejailed plugin error - a collection made a kill request in it's output." >&2
    return_code=151
  fi
  for successful_home_dir in "${successful_home_dirs[@]}"; do
    echo "${successful_home_dir}"
  done
  return "${return_code}"
}
