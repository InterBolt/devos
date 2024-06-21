#!/usr/bin/env bash

. "${HOME}/.solos/repo/shared/lib.sh" || exit 1
. "${HOME}/.solos/repo/daemon/shared.sh" || exit 1
# ------------------------------------------------------------------------
#
# HELPER FUNCTIONS:
#
#-------------------------------------------------------------------------
plugin_phases.merge_assets_args() {
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
    grouped_plugin_expanded_asset_args+=("${str}")
    i=$((i + 1))
  done
  local grouped_plugin_expanded_asset_args_count="${#grouped_plugin_expanded_asset_args[@]}"
  if [[ ${grouped_plugin_expanded_asset_args_count} -ne ${plugin_count} ]]; then
    shared.log_error "Unexpected error - the number of expanded assets does not match the number of plugins (warning, you'll need coffee and bravery for this one)."
    return 1
  fi
  echo "${asset_args[*]}" "${grouped_plugin_expanded_asset_args[${plugin_index}]}" | xargs
}
plugin_phases._validate_firejailed_assets() {
  local asset_firejailed_path="${1}"
  local asset_host_path="${2}"
  local chmod_permission="${3}"
  if [[ -z "${asset_firejailed_path}" ]]; then
    shared.log_error "Unexpected error - empty firejailed path."
    return 1
  fi
  if [[ ! "${asset_firejailed_path}" =~ ^/ ]]; then
    shared.log_error "Unexpected error - firejailed path must start with a \"/\""
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
plugin_phases._merged_namespaced_fs() {
  local namespace="${1}"
  local partial_dir="${2}"
  local merged_dir="${3}"
  local partial_files=($(find "${partial_dir}" -type f | xargs))
  for partial_file in "${partial_files[@]}"; do
    local partial_file_dir="$(dirname "${partial_file}")"
    local partial_file_name="$(basename "${partial_file}")"
    local merged_relative_path="${partial_file_dir#${partial_dir}}"
    local merged_abs_dirpath="${merged_dir}${merged_relative_path}"
    mkdir -p "${merged_abs_dirpath}"
    local merged_file_path="${merged_abs_dirpath}/${namespace}-${partial_file_name}"
    cp "${partial_file}" "${merged_file_path}"
  done
}
plugin_phases._expand_assets() {
  local expanded_asset=($(echo "${1}" | xargs))
  local expanded_asset_path="${2}"
  local expanded_asset_permission="${3}"
  local plugins=($(echo "${4}" | xargs))
  local plugin_names=($(shared.plugin_paths_to_names "${plugins[*]}"))
  local expanded_asset_args=()
  local i=0
  for plugin in "${plugins[@]}"; do
    local plugin_expanded_asset="${expanded_asset[${i}]}"
    if [[ -z "${plugin_expanded_asset}" ]]; then
      expanded_asset_args+=("-" "-" "-")
      i=$((i + 1))
      continue
    fi
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
plugin_phases._firejail() {
  local phase="${1}"
  local phase_cache="${2}"
  local plugins=($(echo "${3}" | xargs))
  local asset_args=($(echo "${4}" | xargs))
  local plugin_expanded_asset_args=($(echo "${5}" | xargs))
  local executable_options=($(echo "${6}" | xargs))
  local merge_path="${7}"
  local firejail_options=($(echo "${8}" | xargs))
  local manifest_file="${9}"
  local aggregated_stdout_file="$(mktemp)"
  local aggregated_stderr_file="$(mktemp)"
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
    local merged_asset_args=($(
      plugin_phases.merge_assets_args \
        "${plugin_count}" \
        "${plugin_index}" \
        "${plugin_expanded_asset_args[*]}" \
        "${asset_args[*]}"
    ))
    local merged_asset_arg_count="${#merged_asset_args[@]}"
    local firejailed_home_dir="$(mktemp -d)"
    local plugin_stdout_file="$(mktemp)"
    local plugin_stderr_file="$(mktemp)"

    # Setup the cache
    local plugin_phase_cache="${phase_cache}/${plugin_name}"
    local firejailed_cache="${firejailed_home_dir}/cache"
    mkdir -p "${plugin_phase_cache}" "${firejailed_cache}"
    cp -rfa "${plugin_phase_cache}"/. "${firejailed_cache}/"
    chmod 777 "${firejailed_cache}"

    # Prepare the assets in the firejailed home directory.
    for ((i = 0; i < ${merged_asset_arg_count}; i++)); do
      if [[ $((i % 3)) -ne 0 ]]; then
        continue
      fi
      local asset_host_path="${merged_asset_args[${i}]}"
      local asset_firejailed_path="${merged_asset_args[$((i + 1))]}"
      local chmod_permission="${merged_asset_args[$((i + 2))]}"
      if [[ ${asset_firejailed_path} != "-" ]]; then
        if ! plugin_phases._validate_firejailed_assets \
          "${asset_firejailed_path}" \
          "${asset_host_path}" \
          "${chmod_permission}"; then
          return 1
        fi
        local asset_firejailed_path="${firejailed_home_dir}${asset_firejailed_path}"
        if [[ -f ${asset_host_path} ]]; then
          cp "${asset_host_path}" "${asset_firejailed_path}"
        elif [[ -d ${asset_host_path} ]]; then
          mkdir -p "${asset_firejailed_path}"
          if ! cp -rfa "${asset_host_path}"/. "${asset_firejailed_path}/"; then
            shared.log_error "Phase:${phase} [error] - failed to copy ${asset_host_path} to ${asset_firejailed_path}."
            return 1
          fi
        fi
        chmod -R "${chmod_permission}" "${asset_firejailed_path}"
      fi
    done

    # Setup the executable and config files.
    cp -a "${plugin_path}/plugin" "${firejailed_home_dir}/plugin"
    local plugin_config_file="${plugin_path}/solos.config.json"
    if [[ -f ${plugin_config_file} ]]; then
      cp "${plugin_config_file}" "${firejailed_home_dir}/solos.config.json"
    else
      echo "{}" >"${firejailed_home_dir}/solos.config.json"
    fi
    if [[ -f ${manifest_file} ]]; then
      # TODO: make sure local plugins are included.
      cp "${manifest_file}" "${firejailed_home_dir}/solos.manifest.json"
    else
      return 1
    fi
    if [[ ! " ${executable_options[@]} " =~ " --phase-configure " ]]; then
      chmod 555 "${firejailed_home_dir}/solos.config.json"
    else
      chmod 777 "${firejailed_home_dir}/solos.config.json"
    fi

    # Run the plugin in a firejail sandbox.
    firejail \
      --quiet \
      --noprofile \
      --private="${firejailed_home_dir}" \
      "${firejail_options[@]}" \
      /root/plugin "${executable_options[@]}" \
      >"${plugin_stdout_file}" 2>"${plugin_stderr_file}" &
    local firejailed_pid=$!
    firejailed_pids+=("${firejailed_pid}")
    firejailed_home_dirs+=("${firejailed_home_dir}")
    plugin_stdout_files+=("${plugin_stdout_file}")
    plugin_stderr_files+=("${plugin_stderr_file}")
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
        echo "(${plugin_name}) ${line}" >>"${aggregated_stdout_file}"
      done <"${plugin_stdout_file}"
    fi
    if [[ -f ${plugin_stderr_file} ]]; then
      while IFS= read -r line; do
        echo "(${plugin_name}) ${line}" >>"${aggregated_stderr_file}"
      done <"${plugin_stderr_file}"
    fi
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      shared.log_warn "Phase:${phase} [error] - ${executable_path} exited with status ${firejailed_exit_code}"
      firejailed_failures=$((firejailed_failures + 1))
    fi
    i=$((i + 1))
  done
  i=0
  for plugin_stderr_file in "${plugin_stderr_files[@]}"; do
    local plugin_name="$(shared.plugin_paths_to_names "${plugins[${i}]}")"
    if grep -q "^SOLOS_PANIC" "${plugin_stderr_file}" >/dev/null 2>/dev/null; then
      firejailed_kills="${firejailed_kills} ${plugin_name}"
    fi
    i=$((i + 1))
  done
  firejailed_kills=($(echo "${firejailed_kills}" | xargs))
  for plugin_stdout_file in "${plugin_stdout_files[@]}"; do
    if grep -q "^SOLOS_PANIC" "${plugin_stdout_file}" >/dev/null 2>/dev/null; then
      shared.log_warn "Phase:${phase} - the plugin sent a panic message to stderr."
    fi
  done
  if [[ ${firejailed_failures} -gt 0 ]]; then
    shared.log_error "Phase:${phase} [error] - there were ${firejailed_failures} total failures across ${plugin_count} plugins."
  fi
  if [[ ${#firejailed_kills[@]} -gt 0 ]]; then
    lib.panics_add "plugin_panics_detected" <<EOF
The following plugins panicked: [${firejailed_kills[*]}] in phase: ${phase}

Once all panic files in ${shared__panics_dir} are removed (and hopefully resolved!), the daemon will restart all plugins from the beginning.

STDERR:
$(cat "${aggregated_stderr_file}")

STDOUT:
$(cat "${aggregated_stdout_file}")
EOF
    shared.log_error "Phase:${phase} [error] - panics detected from: ${firejailed_kills[*]}"
    echo "151"
    return 1
  else
    lib.panics_remove "plugin_panics_detected"
  fi
  local assets_created_by_plugins=()
  local i=0
  if [[ -n ${merge_path} ]]; then
    for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
      local plugin_name="${plugin_names[${i}]}"
      local created_asset="${firejailed_home_dir}${merge_path}"
      assets_created_by_plugins+=("${created_asset}")
      shared.log_info "Phase:${phase} - an asset was created: ${created_asset}"
      rm -rf "${phase_cache}/${plugin_name}"
      mv "${firejailed_home_dir}/cache" "${phase_cache}/${plugin_name}"
      shared.log_info "Phase:${phase} - saved cache to ${phase_cache}/${plugin_name}"
      i=$((i + 1))
    done
  fi
  echo "${aggregated_stdout_file}" | xargs
  echo "${aggregated_stderr_file}" | xargs
  echo "${assets_created_by_plugins[*]}" | xargs
}
# ------------------------------------------------------------------------
#
# ALL PHASES:
#
#-------------------------------------------------------------------------
#
# The configure phase is responsible for making any modifications to the config files associated
# with the plugins. This allows for a simple upgrade path for plugins that need to make changes
# to the way they configs are structured but don't want to depend on users to manually update them.
plugin_phases.configure() {
  local phase_cache="${1}"
  local returned="$(
    plugin_phases._expand_assets \
      "" \
      "" \
      "" \
      "${2}"
  )"
  local manifest_file="${3}"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-configure")
  local firejail_args=("--net=none")
  local asset_args=()
  returned="$(
    plugin_phases._firejail \
      "configure" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/solos.config.json" \
      "${firejail_args[*]}" \
      "${manifest_file}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")" \
  local potentially_updated_configs=($(lib.line_to_args "${returned}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for potentially_updated_config_file in "${potentially_updated_configs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    cp "${potentially_updated_config_file}" "${merge_dir}/${plugin_name}.json"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}" | xargs
  echo "${aggregated_stderr_file}" | xargs
  echo "${merge_dir}" | xargs
}
# The download phase is where plugin authors can pull information from remote resources that they might
# need to process the user's data. This could be anything from downloading a file to making an API request.
plugin_phases.download() {
  local phase_cache="${1}"
  local returned="$(
    plugin_phases._expand_assets \
      "" \
      "" \
      "" \
      "${2}"
  )"
  local manifest_file="${3}"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-download")
  local firejail_args=()
  local asset_args=(
    "$(mktemp -d)" "/download" "777"
  )
  returned="$(
    plugin_phases._firejail \
      "download" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/download" \
      "${firejail_args[*]}" \
      "${manifest_file}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  local download_dirs_created_by_plugins=($(lib.line_to_args "${returned}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for created_download_dir in "${download_dirs_created_by_plugins[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    plugin_phases._merged_namespaced_fs \
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
  local returned="$(
    plugin_phases._expand_assets \
      "${plugin_download_dirs[*]}" \
      "/download" \
      "555" \
      "${5}"
  )"
  local manifest_file="${6}"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-process")
  local firejail_args=("--net=none")
  local asset_args=(
    "$(mktemp)" "/processed.json" "777"
    "${scrubbed_dir}" "/solos" "555"
    "${merged_download_dir}" "/plugins/download" "555"
  )
  returned="$(
    plugin_phases._firejail \
      "process" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/processed.json" \
      "${firejail_args[*]}" \
      "${manifest_file}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  local processed_files_created_by_plugins=($(lib.line_to_args "${returned}" "2"))
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
  local returned="$(
    plugin_phases._expand_assets \
      "${processed_files[*]}" \
      "/processed.json" \
      "555" \
      "${4}"
  )"
  local manifest_file="${5}"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-chunk")
  local firejail_args=()
  local asset_args=(
    "$(mktemp)" "/chunks.log" "777"
    "${merged_processed_dir}" "/plugins/processed" "555"
  )
  returned="$(
    plugin_phases._firejail \
      "chunk" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/chunks.log" \
      "${firejail_args[*]}" \
      "${manifest_file}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  local chunk_log_files_created_by_plugins=($(lib.line_to_args "${returned}" "2"))
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
  local returned="$(
    plugin_phases._expand_assets \
      "${chunk_log_files[*]}" \
      "/chunks.log" \
      "555" \
      "${4}"
  )"
  local manifest_file="${5}"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-publish")
  local firejail_args=()
  local asset_args=(
    "${merged_chunks}" "/plugins/chunks" "555"
  )
  returned="$(
    plugin_phases._firejail \
      "publish" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "" \
      "${firejail_args[*]}" \
      "${manifest_file}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
}
