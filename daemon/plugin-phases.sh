#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/daemon/shared.sh" || exit 1

# SUBPHASES:
# Don't place these in shared quite yet, since the abstraction is a bit leaky
# and the subphases are tightly coupled to the plugin-phases.
plugin_phases.subphase_expanded_assets() {
  local expanded_asset=($(echo "${1}" | xargs))
  local expanded_asset_path="${2}"
  local expanded_asset_permission="${3}"
  local plugins=($(echo "${4}" | xargs))
  local plugin_names=($(shared.plugin_paths_to_names "${plugins[@]}"))
  local expanded_asset_args=()
  local i=0
  for plugin in "${plugins[@]}"; do
    expanded_asset_args+=(
      "${expanded_asset[${i}]}"
      "${expanded_asset_path}"
      "${expanded_asset_permission}"
    )
    i=$((i + 1))
  done
  echo "${plugins[*]}" | xargs
  echo "${plugin_names[*]}" | xargs
  echo "${expanded_asset_args[*]}" | xargs
}
plugin_phases.subphase_firejail() {
  local phase_cache="${1}"
  local plugins=($(echo "${2}" | xargs))
  local assets_args=($(echo "${3}" | xargs))
  local expanded_asset_args=($(echo "${4}" | xargs))
  local executable_args=($(echo "${5}" | xargs))
  local merge_path="${6}"
  local firejail_options=($(echo "${7}" | xargs))
  local aggregated_stdout_file="$(mktemp)"
  local aggregated_stderr_file="$(mktemp)"
  local stashed_firejailed_home_dirs="$(mktemp)"
  shared.firejail \
    "${phase_cache}" \
    "${expanded_asset_args[*]}" \
    "${assets_args[*]}" \
    "${plugins[*]}" \
    "${firejail_options[*]}" \
    "${executable_args[*]}" \
    "${aggregated_stdout_file}" \
    "${aggregated_stderr_file}" >>"${stashed_firejailed_home_dirs}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  local firejailed_home_dirs=()
  while read -r line; do
    firejailed_home_dirs+=("$(echo "${line}" | xargs)")
  done <"${stashed_firejailed_home_dirs}"
  local assets_created_by_plugins=()
  local i=0
  if [[ -n ${merge_path} ]]; then
    for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
      local plugin_name="${plugin_names[${i}]}"
      assets_created_by_plugins+=("${firejailed_home_dir}${merge_path}")
      rm -rf "${phase_cache}/${plugin_name}"
      mv "${firejailed_home_dir}/cache" "${phase_cache}/${plugin_name}"
      i=$((i + 1))
    done
  fi
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${assets_created_by_plugins[*]}"
}
# PHASE DEFINITIONS:
# These should be written in the order they run.
#
# The configure phase is responsible for making any modifications to the config files associated
# with the plugins. This allows for a simple upgrade path for plugins that need to make changes
# to the way they configs are structured but don't want to depend on users to manually update them.
plugin_phases.configure() {
  local phase_cache="${1}"
  local subphase_result="$(
    plugin_phases.subphase_expanded_assets \
      "" \
      "" \
      "" \
      "${2}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local plugins=($(lib.line_to_args "${subphase_result}" "0"))
  local plugin_names=($(lib.line_to_args "${subphase_result}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${subphase_result}" "2"))
  local executable_args=("--phase-configure")
  local firejail_args=()
  local asset_args=()
  local subphase_result="$(
    plugin_phases.subphase_firejail \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_args[*]}" \
      "/solos.json" \
      "${firejail_args[*]}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${subphase_result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${subphase_result}" "1")"
  local potentially_updated_configs=($(lib.line_to_args "${subphase_result}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for potentially_updated_config_file in "${potentially_updated_configs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    cp "${potentially_updated_config_file}" "${merge_dir}/${plugin_name}.json"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${merge_dir}"
  echo "${potentially_updated_configs[*]}"
}
# The download phase is where plugin authors can pull information from remote resources that they might
# need to process the user's data. This could be anything from downloading a file to making an API request.
plugin_phases.download() {
  local phase_cache="${1}"
  local subphase_result="$(
    plugin_phases.subphase_expanded_assets \
      "" \
      "" \
      "" \
      "${2}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local plugins=($(lib.line_to_args "${subphase_result}" "0"))
  local plugin_names=($(lib.line_to_args "${subphase_result}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${subphase_result}" "2"))
  local executable_args=("--phase-download")
  local firejail_args=()
  local asset_args=(
    "$(mktemp -d)" "/download" "777"
  )
  local subphase_result="$(
    plugin_phases.subphase_firejail \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_args[*]}" \
      "/download" \
      "${firejail_args[*]}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${subphase_result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${subphase_result}" "1")"
  local download_dirs_created_by_plugins=($(lib.line_to_args "${subphase_result}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for created_download_dir in "${download_dirs_created_by_plugins[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    shared.merged_namespaced_fs \
      "${plugin_name}" \
      "${created_download_dir}" \
      "${merge_dir}"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${merge_dir}"
  echo "${download_dirs_created_by_plugins[*]}"
}
# The process phase is where the bulk of the work is done This phase has access to the user's scrubbed data
# and the downloaded data from the download phase. During this phase, we cut off access to the network to
# prevent any data exfiltration.
plugin_phases.process() {
  local phase_cache="${1}"
  local scrubbed_dir="${2}"
  local merged_download_dir="${3}"
  local plugin_download_dirs=($(echo "${4}" | xargs))
  local subphase_result="$(
    plugin_phases.subphase_expanded_assets \
      "${plugin_download_dirs[*]}" \
      "/download" \
      "555" \
      "${5}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local plugins=($(lib.line_to_args "${subphase_result}" "0"))
  local plugin_names=($(lib.line_to_args "${subphase_result}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${subphase_result}" "2"))
  local executable_args=("--phase-process")
  local firejail_args=("--net=none")
  local asset_args=(
    "$(mktemp)" "/processed.json" "777"
    "${scrubbed_dir}" "/.solos" "555"
    "${merged_download_dir}" "/plugins/download" "555"
  )
  local subphase_result="$(
    plugin_phases.subphase_firejail \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_args[*]}" \
      "/processed.json" \
      "${firejail_args[*]}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${subphase_result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${subphase_result}" "1")"
  local processed_files_created_by_plugins=($(lib.line_to_args "${subphase_result}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for processed_file in "${processed_files_created_by_plugins[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    cp "${processed_file}" "${merge_dir}/${plugin_name}.json"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${merge_dir}"
  echo "${processed_files_created_by_plugins[*]}"
}
# The chunking phase is where processed data gets converted into text chunks. This is useful when
# designing a RAG query system or a search index.
plugin_phases.chunk() {
  local phase_cache="${1}"
  local merged_processed_dir="${2}"
  local processed_files=("$(echo "${3}" | xargs)")
  local subphase_result="$(
    plugin_phases.subphase_expanded_assets \
      "${processed_files[*]}" \
      "/processed.json" \
      "555" \
      "${4}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local plugins=($(lib.line_to_args "${subphase_result}" "0"))
  local plugin_names=($(lib.line_to_args "${subphase_result}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${subphase_result}" "2"))
  local executable_args=("--phase-chunk")
  local firejail_args=()
  local asset_args=(
    "$(mktemp)" "/chunks.log" "777"
    "${merged_processed_dir}" "/plugins/processed" "555"
  )
  local subphase_result="$(
    plugin_phases.subphase_firejail \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_args[*]}" \
      "/chunks.log" \
      "${firejail_args[*]}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${subphase_result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${subphase_result}" "1")"
  local chunk_log_files_created_by_plugins=($(lib.line_to_args "${subphase_result}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for chunk_log_file in "${chunk_log_files_created_by_plugins[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    cp "${chunk_log_file}" "${merge_dir}/${plugin_name}.log"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${merge_dir}"
  echo "${chunk_log_files_created_by_plugins[*]}"
}
# This phase is responsible for taking the chunks and publishing them to the appropriate remote
# service for custom use cases, such as SMS bots, email alerts, or a company-wide search index.
# Note: this phase doesn't need access to the processed data, only the chunks. This phase and the chunk
# phase have network access, so any kind of publishing that is specific to the processed data
# can be done in the chunk phase. I'm not merging the phases because I want the publish phase to allow
# plugin authors to use all chunks, regardless of which plugin created them.
plugin_phases.publish() {
  local phase_cache="${1}"
  local merged_chunks="${2}"
  local chunk_log_files=("$(echo "${3}" | xargs)")
  local subphase_result="$(
    plugin_phases.subphase_expanded_assets \
      "${chunk_log_files[*]}" \
      "/chunks.log" \
      "555" \
      "${4}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local plugins=($(lib.line_to_args "${subphase_result}" "0"))
  local plugin_names=($(lib.line_to_args "${subphase_result}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${subphase_result}" "2"))
  local executable_args=("--phase-publish")
  local firejail_args=()
  local asset_args=(
    "${merged_chunks}" "/plugins/chunks" "555"
  )
  local subphase_result="$(
    plugin_phases.subphase_firejail \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_args[*]}" \
      "" \
      "${firejail_args[*]}" || echo "$?"
  )"
  if [[ ${subphase_result} -eq 151 ]]; then
    return "${subphase_result}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${subphase_result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${subphase_result}" "1")"
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
}
