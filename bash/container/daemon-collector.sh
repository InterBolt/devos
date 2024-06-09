#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_collector.log_info() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.info "${message}" "$@"
}
daemon_collector.log_error() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.error "${message}" "$@"
}
daemon_collector.log_warn() {
  local message="(COLLECTOR) ${1} pid=\"${daemon_main__pid}\""
  shift
  log.warn "${message}" "$@"
}

# Grab all executable files and make sure we're going to be able to run them.
daemon_collector._get_executables() {
  local plugin_executables=()
  local plugins="${*}"
  for plugin in ${plugins}; do
    if [[ -f "${plugin}/collector" ]]; then
      chmod +x "${plugin}/collector"
      plugin_executables+=("${plugin}/collector")
    fi
  done
  echo "${plugin_executables[*]}"
}
daemon_collector._execute() {
  local scrubbed_copy="${1}"
  shift

  # Kick off a firejailed process for each executable and collect the pids
  # for each backgrounded process. We'll wait on them later.
  local executable_paths="${*}"
  local firejailed_pids=()
  local firejailed_home_dir=()
  local firejailed_stdout_files=()
  local firejailed_stderr_files=()
  for executable_path in ${executable_paths}; do
    local firejailed_home_dir="$(mktemp -d)"
    local firejailed_collections_dir="$(mktemp -d)"
    local firejailed_stdout_file="$(mktemp)"
    local firejailed_stderr_file="$(mktemp)"
    mkdir -p "${firejailed_home_dir}/.solos"
    cp -r "${scrubbed_copy}/." "${firejailed_home_dir}/.solos/"
    cp -a "${executable_path}" "${firejailed_home_dir}/executable"
    mv "${firejailed_collections_dir}" "${firejailed_home_dir}/collections"
    firejail \
      --quiet \
      --noprofile \
      --net=none \
      --private="${firejailed_home_dir}" \
      /root/executable >>"${firejailed_stdout_file}" 2>>"${firejailed_stderr_file}" &
    local firejailed_pid=$!
    firejailed_pids+=("${firejailed_pid}")
    firejailed_home_dir+=("${home_dir}")
    firejailed_stdout_files+=("${firejailed_stdout_file}")
    firejailed_stderr_files+=("${firejailed_stderr_file}")
  done

  local firejailed_requesting_kill=false
  local firejailed_failures=0
  local final_collection_dirs=()
  local i=0
  for firejailed_pid in "${firejailed_pids[@]}"; do
    # Wait on each firejailed process and log any output. Handle a specific type of
    # output that indicates the collector was killed by SolOS.
    wait "${firejailed_pid}"
    local firejailed_exit_code=$?
    local executable_path="${executable_paths[${i}]}"
    local firejailed_stdout_file="${firejailed_stdout_files[${i}]}"
    local firejailed_stderr_file="${firejailed_stderr_files[${i}]}"
    if [[ -f ${firejailed_stdout_file} ]] && grep -q "^SOLOS_KILL" "${firejailed_stdout_file}" >/dev/null 2>/dev/null; then
      firejailed_requesting_kill=true
    fi
    if [[ -f ${firejailed_stderr_file} ]] && grep -q "^SOLOS_KILL" "${firejailed_stderr_file}" >/dev/null 2>/dev/null; then
      firejailed_requesting_kill=true
    fi
    if [[ -f ${firejailed_stderr_file} ]]; then
      while read -r firejailed_stderr_line; do
        daemon_collector.log_error "$(dirname "${executable_path}") - ${firejailed_stderr_line}"
      done <"${firejailed_stderr_file}"
    fi
    if [[ -f ${firejailed_stdout_file} ]]; then
      while read -r firejailed_stdout_line; do
        daemon_collector.log_info "$(dirname "${executable_path}") - ${firejailed_stdout_line}"
      done <"${firejailed_stdout_file}"
    fi
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      daemon_collector.log_error "Plugin malfunction - the collector at ${executable_path} exited with status ${firejailed_exit_code}"
      firejailed_failures=$((firejailed_failures + 1))
      # Must maintain order
      final_collection_dirs+=("-")
    else
      local sandboxed_collections_dir="${firejailed_home_dir[${i}]}/collections"
      if [[ ! -d ${sandboxed_collections_dir} ]]; then
        daemon_collector.log_warn "Plugin malfunction - the collector at ${executable_path} must have deleted its collections directory."
        # Must maintain order
        final_collection_dirs+=("-")
      else
        final_collection_dirs+=("${sandboxed_collections_dir}")
      fi
    fi
    i=$((i + 1))
  done
  local return_code=0
  if [[ ${firejailed_failures} -gt 0 ]]; then
    daemon_collector.log_error "Plugin malfunction - there were ${firejailed_failures} plugin malfunctions."
  fi
  if [[ ${firejailed_requesting_kill} = true ]]; then
    daemon_collector.log_error "Plugin malfunction - a collector made a kill request in it's output."
    return_code=151
  fi
  # Even when a collector fails, it still adds a dash to the list of collections dirs.
  # This guarantees that we echo one line per collector, which makes it easier to parse the output.
  for final_collection_dir in "${final_collection_dirs[@]}"; do
    echo "${final_collection_dir}"
  done
  return ${return_code}
}
daemon_collector._mv_to_shared() {
  local unique_plugin_namespace="${1}"
  local sandboxed_collections_dir="${2}"
  local merged_collections_dir="${3}"
  local sandboxed_files="$(find "${sandboxed_collections_dir}" -type f | xargs)"
  for sandboxed_file in ${sandboxed_files}; do
    local sandboxed_file_dir="$(dirname "${sandboxed_file}")"
    local sandboxed_file_name="$(basename "${sandboxed_file}")"
    local merged_relative_path="${sandboxed_file_dir#${sandboxed_collections_dir}}"
    local merged_abs_dirpath="${merged_collections_dir}${merged_relative_path}"
    mkdir -p "${merged_abs_dirpath}"
    local merged_file_path="${merged_abs_dirpath}/${unique_plugin_namespace}-${sandboxed_file_name}"
    # The result is if the plugin created a file sandboxed/foo/bar.txt, it will be moved to
    # merged/sandboxed/foo/internal-plugin-name-bar.txt (or whatever the unique_plugin_namespace is)
    mv "${sandboxed_file}" "${merged_file_path}"
  done
}
daemon_collector.main() {
  # The scrubbed copy is everything in the user's ~/.solos directory devoid of
  # 1) potentially sensitive files based on a blacklist of extensions (it's a bit aggressive. might need changes)
  # 2) .gitignored files/folders
  # 3) secrets found in any .env* files, ~/.solos/secrets dirs, or ~/.solos/projects/<...>/secrets dirs
  local scrubbed_copy="${1}"
  local merged_collections_dir="${2}"

  # Were it not for security concerns, we'd simply mount a shared folder to each
  # collector's firejailed process and let them write their output there, relying on the due dilligence
  # of plugin authors to avoid file collisions.
  # But, for max sandboxing, we don't want collectors to gain the ability to "communicate" across plugins via such shared folders.
  # So instead, after a collector runs, we'll rename all files in each collector's outputted folder with a unique prefix.
  # Then, recursively copy each collector's output dir's contents to a single new folder that our processors can use.
  # Collisions aren't possible due to the prefixes. But categorical folders are still used to keep things organized and to ensure maximum
  # backwards compatibility with existing processors.
  #
  # Extra unrelated note: while I don't normally endorse engineering for speculative use-cases, I believe the SolOS plugin
  # design will almost certain end up with a permission system, even if it's just trusted/untrusted. That's why we need full sandboxing
  # not just between a collector and our system, but also a collector and other collectors. If from day we only add "trusted" plugins,
  # introducing the concept of "untrusted" plugins should not result in a major version bump.

  # Get the executables and unique names of internal/external collectors.
  local unique_plugin_names=()
  local precheck_executables="$(daemon_collector._get_executables "$(daemon_shared.get_precheck_plugins | xargs)" | xargs)"
  for precheck_executable in ${precheck_executables}; do
    unique_plugin_names+=("precheck-$(basename "$(dirname "${precheck_executable}")")")
  done
  local internal_executables="$(daemon_collector._get_executables "$(daemon_shared.get_internal_plugins | xargs)" | xargs)"
  for internal_executable in ${internal_executables}; do
    unique_plugin_names+=("internal-$(basename "$(dirname "${internal_executable}")")")
  done
  local external_executables="$(daemon_collector._get_executables "$(daemon_shared.get_external_plugins | xargs)" | xargs)"
  for external_executable in ${external_executables}; do
    unique_plugin_names+=("external-$(basename "$(dirname "${external_executable}")")")
  done

  # Internal plugins should never fail since external plugins might depend on state that internal plugins provides.
  # Necessary pre-requisite for pushing more and more key functionality into internal plugins rather than bloating
  # SolOS with tons of baked-features.
  local stashed_firejailed_collection_dirs="$(mktemp)"
  if ! daemon_collector._execute "${scrubbed_copy}" "${precheck_executables[@]}" >>"${stashed_firejailed_collection_dirs}"; then
    return "${?}"
  fi
  if ! daemon_collector._execute "${scrubbed_copy}" "${internal_executables[@]}" >>"${stashed_firejailed_collection_dirs}"; then
    return "${?}"
  fi
  # Installed plugins can fail since they're not guaranteed to be well-behaved and we don't want one shitty
  # plugin to prevent the rest from running.
  daemon_collector._execute "${scrubbed_copy}" "${external_executables[@]}" >>"${stashed_firejailed_collection_dirs}"
  local externals_exit_code="${?}"
  # We only allow external plugins to cause the collector to faile when a 151 exit code is returned,
  # which here means that a plugin requested to kill the collector.
  if [[ ${externals_exit_code} -eq 151 ]]; then
    return "${externals_exit_code}"
  fi

  # Every line of stashed_firejailed_collection_dirs is path to a plugin's output directory.
  # The lines are in order of the plugin's order in the unique_plugin_names array so we can access
  # the unique_plugin_name for each plugin by index.
  local firejailed_collection_dirs=""
  while read -r line; do
    firejailed_collection_dirs="${firejailed_collection_dirs} ${line}"
  done <"${stashed_firejailed_collection_dirs}"
  firejailed_collection_dirs="$(echo "${firejailed_collection_dirs}" | xargs)"

  local i=0
  for firejailed_collection_dir in ${firejailed_collection_dirs}; do
    if [[ ${firejailed_collection_dir} != "-" ]]; then
      local unique_plugin_name="${unique_plugin_names[${i}]}"
      daemon_collector._mv_to_shared "${unique_plugin_name}" "${firejailed_collection_dir}" "${merged_collections_dir}"
    fi
    i=$((i + 1))
  done

  echo "${merged_collections_dir}"
}
