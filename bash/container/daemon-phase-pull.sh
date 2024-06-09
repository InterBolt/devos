#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_phase_pull.log_info() {
  local message="(PULL) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.info "${message}" "$@"
}
daemon_phase_pull.log_error() {
  local message="(PULL) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.error "${message}" "$@"
}
daemon_phase_pull.log_warn() {
  local message="(PULL) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.warn "${message}" "$@"
}

# Grab all executable files and make sure we're going to be able to run them.
daemon_phase_pull._get_executables() {
  local plugin_executables=()
  local plugins="${*}"
  for plugin in ${plugins}; do
    if [[ -f "${plugin}/pull" ]]; then
      chmod +x "${plugin}/pull"
      plugin_executables+=("${plugin}/pull")
    fi
  done
  echo "${plugin_executables[*]}"
}
daemon_phase_pull._execute() {
  local cache_dir="${1}"
  local namespace="${2}"
  shift
  # Kick off a firejailed process for each executable and collect the pids
  # for each backgrounded process. We'll wait on them later.
  local executable_paths="${*}"
  local firejailed_pids=()
  local firejailed_home_dir=()
  local firejailed_stdout_files=()
  local firejailed_stderr_files=()
  for executable_path in ${executable_paths}; do
    local plugin_name="$(basename "$(dirname "${executable_path}")")"
    local namespaced_cache_dir="${cache_dir}/${namespace}-${name}"
    mkdir -p "${namespaced_cache_dir}"
    local firejailed_home_dir="$(mktemp -d)"
    local firejailed_stdout_file="$(mktemp)"
    local firejailed_stderr_file="$(mktemp)"
    mkdir -p "${firejailed_home_dir}/data"
    mkdir -p "${firejailed_home_dir}/cache"
    cp -r "${namespaced_cache_dir}/." "${firejailed_home_dir}/cache/"
    cp -a "${executable_path}" "${firejailed_home_dir}/executable"
    firejail \
      --quiet \
      --noprofile \
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
  local final_data_dirs=()
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
        daemon_phase_pull.log_error \
          "$(dirname "${executable_path}") - ${firejailed_stderr_line}"
      done <"${firejailed_stderr_file}"
    fi
    if [[ -f ${firejailed_stdout_file} ]]; then
      while read -r firejailed_stdout_line; do
        daemon_phase_pull.log_info \
          "$(dirname "${executable_path}") - ${firejailed_stdout_line}"
      done <"${firejailed_stdout_file}"
    fi
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      daemon_phase_pull.log_error \
        "Plugin malfunction - the collector at ${executable_path} exited with status ${firejailed_exit_code}"
      firejailed_failures=$((firejailed_failures + 1))
      # Must maintain order
      final_data_dirs+=("-")
    else
      local sandboxed_data_dir="${firejailed_home_dir[${i}]}/data"
      if [[ ! -d ${sandboxed_data_dir} ]]; then
        daemon_phase_pull.log_warn \
          "Plugin malfunction - the collector at ${executable_path} must have deleted its collections directory."
        # Must maintain order
        final_data_dirs+=("-")
      else
        final_data_dirs+=("${sandboxed_data_dir}")
      fi
    fi
    i=$((i + 1))
  done
  local return_code=0
  if [[ ${firejailed_failures} -gt 0 ]]; then
    daemon_phase_pull.log_error \
      "Plugin malfunction - there were ${firejailed_failures} plugin malfunctions."
  fi
  if [[ ${firejailed_requesting_kill} = true ]]; then
    daemon_phase_pull.log_error \
      "Plugin malfunction - a collector made a kill request in it's output."
    return_code=151
  fi
  # Even when a collector fails, it still adds a dash to the list of collections dirs.
  # This guarantees that we echo one line per collector, which makes it easier to parse the output.
  for final_data_dir in "${final_data_dirs[@]}"; do
    echo "${final_data_dir}"
  done
  return "${return_code}"
}
daemon_phase_pull._mv_to_shared() {
  local unique_plugin_namespace="${1}"
  local sandboxed_data_dir="${2}"
  local merged_dir="${3}"
  local sandboxed_files="$(find "${sandboxed_data_dir}" -type f | xargs)"
  for sandboxed_file in ${sandboxed_files}; do
    local sandboxed_file_dir="$(dirname "${sandboxed_file}")"
    local sandboxed_file_name="$(basename "${sandboxed_file}")"
    local merged_relative_path="${sandboxed_file_dir#${sandboxed_data_dir}}"
    local merged_abs_dirpath="${merged_dir}${merged_relative_path}"
    mkdir -p "${merged_abs_dirpath}"
    local merged_file_path="${merged_abs_dirpath}/${unique_plugin_namespace}-${sandboxed_file_name}"
    # The result is if the plugin created a file sandboxed/foo/bar.txt, it will be moved to
    # merged/sandboxed/foo/internal-plugin-name-bar.txt (or whatever the unique_plugin_namespace is)
    mv "${sandboxed_file}" "${merged_file_path}"
  done
}
daemon_phase_pull.main() {
  local pulled_data_dir="$1"
  local cache_dir="$2"

  # Get the executables and unique names of internal/external collectors.
  local unique_plugin_names=()
  local precheck_executables="$(daemon_phase_pull._get_executables "$(daemon_shared.get_precheck_plugins | xargs)" | xargs)"
  for precheck_executable in ${precheck_executables}; do
    unique_plugin_names+=("precheck-$(basename "$(dirname "${precheck_executable}")")")
  done
  local internal_executables="$(daemon_phase_pull._get_executables "$(daemon_shared.get_internal_plugins | xargs)" | xargs)"
  for internal_executable in ${internal_executables}; do
    unique_plugin_names+=("internal-$(basename "$(dirname "${internal_executable}")")")
  done
  local external_executables="$(daemon_phase_pull._get_executables "$(daemon_shared.get_external_plugins | xargs)" | xargs)"
  for external_executable in ${external_executables}; do
    unique_plugin_names+=("external-$(basename "$(dirname "${external_executable}")")")
  done

  local stashed_firejailed_data_dirs="$(mktemp)"
  if ! daemon_phase_pull._execute \
    "${cache_dir}" "precheck" "${precheck_executables[@]}" >>"${stashed_firejailed_data_dirs}"; then
    return "${?}"
  fi
  if ! daemon_phase_pull._execute \
    "${cache_dir}" "internal" "${internal_executables[@]}" >>"${stashed_firejailed_data_dirs}"; then
    return "${?}"
  fi

  daemon_phase_pull._execute \
    "${cache_dir}" "external" "${external_executables[@]}" >>"${stashed_firejailed_data_dirs}"
  local externals_exit_code="${?}"
  if [[ ${externals_exit_code} -eq 151 ]]; then
    return "${externals_exit_code}"
  fi

  local firejailed_data_dirs=""
  while read -r line; do
    firejailed_data_dirs="${firejailed_data_dirs} ${line}"
  done <"${stashed_firejailed_data_dirs}"
  firejailed_data_dirs="$(echo "${firejailed_data_dirs}" | xargs)"

  local i=0
  for firejailed_data_dir in ${firejailed_data_dirs}; do
    if [[ ${firejailed_data_dir} != "-" ]]; then
      local unique_plugin_name="${unique_plugin_names[${i}]}"
      daemon_phase_pull._mv_to_shared "${unique_plugin_name}" "${firejailed_data_dir}" "${pulled_data_dir}"
    fi
    i=$((i + 1))
  done

  echo "${pulled_data_dir}"
}
