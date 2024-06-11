#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

# SHARED/SOURCED FUNCTIONS:

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
daemon_shared.firejail() {
  local assets=()
  local asset_args_count=0
  local args=("${@}")
  local seperator_exists=false
  for arg in "${args[@]}"; do
    if [[ ${arg} = "--" ]]; then
      seperator_exists=true
    fi
  done
  if [[ ${seperator_exists} = false ]]; then
    echo "Firejailed plugin error - invalid argument list. No seperator '--' found in the firejail function." >&2
    return 1
  fi
  while [[ -z ${1} ]] && [[ ${1} != "--" ]]; do
    asset_args_count=$((asset_args_count + 1))
    local divider_arg_is_next=false
    if [[ ${2} = "--" ]]; then
      divider_arg_is_next=true
    fi
    if [[ $((asset_args_count % 3)) -ne 0 ]] && [[ ${divider_arg_is_next} = true ]]; then
      echo "Firejailed plugin error - invalid argument list supplied to the daemon's shared firejail function" >&2
      return 1
    fi
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
  local stdout_file="${1}"
  local stderr_file="${2}"
  if [[ ! -f ${stdout_file} ]]; then
    echo "Firejailed plugin error - no stdout file was provided to the shared firejail function" >&2
    return 1
  fi
  if [[ ! -f ${stderr_file} ]]; then
    echo "Firejailed plugin error - no stderr file was provided to the shared firejail function" >&2
    return 1
  fi
  local asset_count=$((asset_count / 3))
  local firejailed_pids=()
  local firejailed_home_dirs=()
  local firejailed_stdout_files=()
  local firejailed_stderr_files=()
  for plugin in "${plugins[@]}"; do
    local firejailed_home_dir="$(mktemp -d)"
    for ((i = 0; i < ${asset_count}; i++)); do
      if [[ $((i % 3)) -ne 0 ]]; then
        continue
      fi
      local mount_path="${assets[${i}]}"
      local src_path="${assets[$((i + 1))]}"
      local permissions="${assets[$((i + 2))]}"
      if [[ -f ${src_path} ]]; then
        cp "${src_path}" "${firejailed_home_dir}/${mount_path}"
      elif [[ -d ${src_path} ]]; then
        mkdir -p "${firejailed_home_dir}/${mount_path}"
        cp -r "${src_path}" "${firejailed_home_dir}/${mount_path}/"
      else
        echo "Firejailed plugin error - invalid asset path supplied to the daemon's shared firejail function" >&2
        return 1
      fi
      cp -a "${plugin}" "${firejailed_home_dir}/plugin"
      local plugin_config_file="${plugin}/solos.json"
      if [[ -f ${plugin_config_file} ]]; then
        cp "${plugin_config_file}" "${firejailed_home_dir}/solos.json"
      fi
      if [[ ${permissions} = "ro" ]]; then
        chmod -R 555 "${firejailed_home_dir}/${mount_path}"
      elif [[ ${permissions} = "rw" ]]; then
        chmod -R 777 "${firejailed_home_dir}/${mount_path}"
      fi
      firejail \
        --quiet \
        --noprofile \
        --private="${firejailed_home_dir}" \
        "${firejail_options[@]}" \
        /root/plugin "${executable_options[@]}" >>"${firejailed_stdout_file}" 2>>"${firejailed_stderr_file}" &
      local firejailed_pid=$!
      firejailed_pids+=("${firejailed_pid}")
      firejailed_home_dirs+=("${firejailed_home_dir}")
      firejailed_stdout_files+=("${firejailed_stdout_file}")
      firejailed_stderr_files+=("${firejailed_stderr_file}")
    done
  done

  local firejailed_requesting_kill=false
  local firejailed_failures=0
  local successful_home_dirs=()
  local i=0
  for firejailed_pid in "${firejailed_pids[@]}"; do
    # Wait on each firejailed process and log any output. Handle a specific type of
    # output that indicates the collection was killed by SolOS.
    wait "${firejailed_pid}"
    local firejailed_exit_code=$?
    local executable_path="${plugins[${i}]}"
    local firejailed_home_dir="${firejailed_home_dirs[${i}]}"
    chmod -R 777 "${firejailed_home_dir}"
    local firejailed_stdout_file="${firejailed_stdout_files[${i}]}"
    local firejailed_stderr_file="${firejailed_stderr_files[${i}]}"
    if [[ -f ${firejailed_stderr_file} ]]; then
      while IFS= read -r line; do
        echo "firejail-${i}: ${line}" >>"${stderr_file}"
      done <"${firejailed_stderr_file}"
    fi
    if [[ -f ${firejailed_stdout_file} ]]; then
      while IFS= read -r line; do
        echo "firejail-${i}: ${line}" >>"${stdout_file}"
      done <"${firejailed_stdout_file}"
    fi
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      echo "Firejailed plugin error - ${executable_path} exited with status ${firejailed_exit_code}" >&2
      firejailed_failures=$((firejailed_failures + 1))
      successful_home_dirs+=("-")
    else
      successful_home_dirs+=("${firejailed_home_dir}")
    fi
    i=$((i + 1))
  done
  if grep -q "^SOLOS_PANIC" "${stderr_file}" >/dev/null 2>/dev/null; then
    firejailed_requesting_kill=true
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
