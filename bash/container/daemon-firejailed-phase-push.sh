#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_firejailed_phase_push.main() {
  local merged_process_dir="${1}"
  shift 1
  local plugin_processed_files=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    plugin_processed_files+=("${1}")
    shift
  done
  shift
  local plugins=("${@}")
  local plugin_names=($(daemon_shared.plugin_paths_to_names "${plugins[@]}"))
  local raw_stdout_file="$(mktemp)"
  local raw_stderr_file="$(mktemp)"
  local stashed_firejailed_home_dirs="$(mktemp)"
  local firejail_options=()
  local plugin_expanded_assets=()
  local i=0
  for plugin in "${plugins[@]}"; do
    plugin_expanded_assets+=("${plugin_processed_files[${i}]}" "/processed.json" "555")
    i=$((i + 1))
  done
  daemon_shared.firejail \
    "${plugin_expanded_assets[@]}" \
    "--" \
    "${merged_process_dir}" "/plugins/processed" "555" \
    "$(mktemp -d)" "/pushed" "777" \
    "--" \
    "${plugins[@]}" \
    "--" \
    "${firejail_options[@]}" \
    "--" \
    "--phase-push" >>"${stashed_firejailed_home_dirs}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  local firejailed_home_dirs=()
  while read -r line; do
    firejailed_home_dirs+=("$(echo "${line}" | xargs)")
  done <"${stashed_firejailed_home_dirs}"
  local merged_pushed_dir="$(mktemp -d)"
  local decoded_stderr_file="$(mktemp)"
  local decoded_stdout_file="$(mktemp)"
  local i=0
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    daemon_shared.decode_dumped_output \
      "${plugin_name}" \
      "${raw_stdout_file}" "${raw_stderr_file}" \
      "${decoded_stdout_file}" "${decoded_stderr_file}"
    daemon_shared.merged_namespaced_fs \
      "${plugin_name}" \
      "${firejailed_home_dir}/pushed" \
      "${merged_pushed_dir}"
    i=$((i + 1))
  done
  echo "${decoded_stdout_file}"
  echo "${decoded_stderr_file}"
  echo "${merged_pushed_dir}"
}
