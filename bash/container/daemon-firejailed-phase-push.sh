#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_phase_push.log_info() {
  local message="(PUSH) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.info "${message}" "$@"
}
daemon_phase_push.log_error() {
  local message="(PUSH) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.error "${message}" "$@"
}
daemon_phase_push.log_warn() {
  local message="(PUSH) ${1} pid=\"$(cat "${HOME}/.solos/data/daemon/pid" 2>/dev/null || echo "")\""
  shift
  log.warn "${message}" "$@"
}

daemon_phase_push.exec() {
  local scrubbed_dir="${1}"
  local download_dir="${2}"
  local stdout_file="${3}"
  local stderr_file="${4}"
  shift 4
  daemon_shared.firejail \
    "${scrubbed_dir}" "/root/.solos" "rw" \
    "${download_dir}" "/root/data" "rw" \
    "$(mktemp -d)" "/root/collections" "rw" \
    "--" \
    "${@}" \
    "--" \
    --net=none # firejail options
}
daemon_phase_push.main() {
  # The scrubbed copy is everything in the user's ~/.solos directory devoid of
  # 1) potentially sensitive files based on a blacklist of extensions (it's a bit aggressive. might need changes)
  # 2) .gitignored files/folders
  # 3) secrets found in any .env* files, ~/.solos/secrets dirs, or ~/.solos/projects/<projects>/secrets dirs
  local scrubbed_dir="${1}"
  local download_dir="${2}"
  local merged_collections_dir="${3}"

  # Get the executables and unique names of internal/external collections.
  local internal_executables="$(daemon_shared.executables "$(daemon_shared.get_internal_plugins | xargs)" | xargs)"
  if [[ -z ${internal_executables} ]]; then
    return 1
  fi
  local external_executables="$(daemon_shared.executables "$(daemon_shared.get_external_plugins | xargs)" | xargs)"
  if [[ -z ${external_executables} ]]; then
    return 1
  fi
  local unique_plugin_names=()
  for internal_executable in ${internal_executables}; do
    unique_plugin_names+=("internal-$(basename "$(dirname "${internal_executable}")")")
  done
  for external_executable in ${external_executables}; do
    unique_plugin_names+=("external-$(basename "$(dirname "${external_executable}")")")
  done

  local stdout_file="$(mktemp)"
  local stderr_file="$(mktemp)"
  # Internal plugins should never fail since external plugins might depend on state that internal plugins provides.
  # Necessary pre-requisite for pushing more and more key functionality into internal plugins rather than bloating
  # SolOS with tons of baked-features.
  local stashed_firejailed_home_dirs="$(mktemp)"
  if ! daemon_phase_push.exec \
    "${scrubbed_dir}" "${download_dir}" "${stdout_file}" "${stderr_file}" \
    "${internal_executables[@]}" >>"${stashed_firejailed_home_dirs}"; then
    return "${?}"
  fi

  # Installed plugins can fail since they're not guaranteed to be well-behaved and we don't want one shitty
  # plugin to prevent the rest from running.
  daemon_phase_push.exec \
    "${scrubbed_dir}" "${download_dir}" "${stdout_file}" "${stderr_file}" \
    "${external_executables[@]}" >>"${stashed_firejailed_home_dirs}"
  local externals_exit_code="${?}"
  # We only allow external plugins to cause the collection to faile when a 151 exit code is returned,
  # which here means that a plugin requested to kill the collection.
  if [[ ${externals_exit_code} -eq 151 ]]; then
    return "${externals_exit_code}"
  fi

  # Every line of stashed_firejailed_home_dirs is path to a plugin's output directory.
  # The lines are in order of the plugin's order in the unique_plugin_names array so we can access
  # the unique_plugin_name for each plugin by index.
  local firejailed_home_dirs=()
  while read -r line; do
    firejailed_home_dirs+=("$(echo "${line}" | xargs)")
  done <"${stashed_firejailed_home_dirs}"

  local prefixed_stderr_file="$(mktemp)"
  local prefixed_stdout_file="$(mktemp)"
  local i=0
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    local unique_plugin_name="${unique_plugin_names[${i}]}"
    while IFS= read -r line; do
      if [[ ${line} =~ ^firejail-${i}: ]]; then
        line="${line//firejail-${i}: /}"
        echo "(${unique_plugin_name}) ${line}" >>"${prefixed_stderr_file}"
      fi
    done <"${stderr_file}"
    while IFS= read -r line; do
      if [[ ${line} =~ ^firejail-${i}: ]]; then
        line="${line//firejail-${i}: /}"
        echo "(${unique_plugin_name}) ${line}" >>"${prefixed_stdout_file}"
      fi
    done <"${stdout_file}"
    if [[ ${firejailed_home_dir} != "-" ]]; then
      daemon_shared.merged_namespaced_fs \
        "${unique_plugin_name}" \
        "${firejailed_home_dir}/collection" \
        "${merged_collections_dir}"
    fi
    i=$((i + 1))
  done

  echo "${merged_collections_dir} ${prefixed_stdout_file} ${prefixed_stderr_file}"
}
