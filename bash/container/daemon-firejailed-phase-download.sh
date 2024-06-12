#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_firejailed_phase_download.main() {
  local plugins=("${@}")
  local plugin_names=($(daemon_shared.plugin_paths_to_names "${plugins[@]}"))
  local raw_stdout_file="$(mktemp)"
  local raw_stderr_file="$(mktemp)"
  local stashed_firejailed_home_dirs="$(mktemp)"
  local firejail_options=()
  daemon_shared.firejail \
    "--" \
    "$(mktemp -d)" "/download" "777" \
    "--" \
    "${plugins[@]}" \
    "--" \
    "${firejail_options[@]}" \
    "--" \
    "--phase-download" >>"${stashed_firejailed_home_dirs}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi

  # Every line of stashed_firejailed_home_dirs is path to a plugin's output directory.
  # The lines are in order of the plugin's order in the plugin_names array so we can access
  # the plugin_name for each plugin by index.
  local firejailed_home_dirs=()
  while read -r line; do
    firejailed_home_dirs+=("$(echo "${line}" | xargs)")
  done <"${stashed_firejailed_home_dirs}"

  local merged_download_dir="$(mktemp -d)"
  local decoded_stderr_file="$(mktemp)"
  local decoded_stdout_file="$(mktemp)"
  local plugin_download_dirs=()
  local i=0
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    daemon_shared.decode_dumped_output \
      "${plugin_name}" \
      "${raw_stdout_file}" "${raw_stderr_file}" \
      "${decoded_stdout_file}" "${decoded_stderr_file}"
    plugin_download_dirs+=("${firejailed_home_dir}/download")
    daemon_shared.merged_namespaced_fs \
      "${plugin_name}" \
      "${firejailed_home_dir}/download" \
      "${merged_download_dir}"
    i=$((i + 1))
  done

  echo "${decoded_stdout_file}"
  echo "${decoded_stderr_file}"
  echo "${merged_download_dir}"
  echo "${plugin_download_dirs[*]}"
}
