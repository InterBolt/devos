#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_firejailed_phase_process.log_info() {
  local message="(PHASE:PROCESS) ${1}"
  shift
  log.info "${message}" "$@"
}
daemon_firejailed_phase_process.log_error() {
  local message="(PHASE:PROCESS) ${1}"
  shift
  log.error "${message}" "$@"
}
daemon_firejailed_phase_process.log_warn() {
  local message="(PHASE:PROCESS) ${1}"
  shift
  log.warn "${message}" "$@"
}
daemon_firejailed_phase_process.main() {
  local scrubbed_dir="${1}"
  local merged_download_dir="${2}"
  local merged_collection_dir="${3}"
  shift 3
  local plugin_collection_dirs=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    plugin_collection_dirs+=("${1}")
    shift
  done
  shift
  local plugin_download_dirs=()
  while [[ -n ${1} ]] && [[ ${1} != "--" ]]; do
    plugin_download_dirs+=("${1}")
    shift
  done
  shift
  local plugins=("${@}")
  local plugin_names=($(daemon_shared.plugin_paths_to_names "${plugins[@]}"))
  local raw_stdout_file="$(mktemp)"
  local raw_stderr_file="$(mktemp)"
  local stashed_firejailed_home_dirs="$(mktemp)"
  local firejail_options=("--net=none")
  local plugin_expanded_assets=()
  local i=0
  for plugin in "${plugins[@]}"; do
    plugin_expanded_assets+=("${plugin_collection_dirs[${i}]}" "/collection" "555")
    i=$((i + 1))
  done
  daemon_shared.firejail \
    "${plugin_expanded_assets[@]}" \
    "--" \
    "${scrubbed_dir}" "/.solos" "555" \
    "${merged_collection_dir}" "/plugins/collection" "555" \
    "$(mktemp)" "/processed.json" "777" \
    "--" \
    "${plugins[@]}" \
    "--" \
    "${firejail_options[@]}" \
    "--" \
    "--phase-process" >>"${stashed_firejailed_home_dirs}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  local firejailed_home_dirs=()
  while read -r line; do
    firejailed_home_dirs+=("$(echo "${line}" | xargs)")
  done <"${stashed_firejailed_home_dirs}"
  local merged_processed="$(mktemp -d)"
  local decoded_stderr_file="$(mktemp)"
  local decoded_stdout_file="$(mktemp)"
  local processed_files=()
  local i=0
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    daemon_shared.decode_dumped_output \
      "(${plugin_name})" \
      "${raw_stdout_file}" "${raw_stderr_file}" \
      "${decoded_stdout_file}" "${decoded_stderr_file}"
    processed_files+=("${firejailed_home_dir}/processed.json")
    cp "${firejailed_home_dir}/processed.json" "${merged_processed}/${plugin_name}-processed.json"
    i=$((i + 1))
  done
  echo "${decoded_stdout_file}"
  echo "${decoded_stderr_file}"
  echo "${merged_processed}"
  echo "${processed_files[*]}"
}
