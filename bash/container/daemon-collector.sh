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

daemon_collector._run() {
  local scrubbed_solos_dir="${1}"
  local executable_path="${2}"
  local sandbox_home_dir="$(mktemp -d)"
  local sandbox_collections_dir="$(mktemp -d)"
  local stdout_file="$(mktemp)"
  local stderr_file="$(mktemp)"
  mkdir -p "${sandbox_home_dir}/.solos"
  cp -r "${scrubbed_solos_dir}/." "${sandbox_home_dir}/.solos/"
  cp -a "${executable_path}" "${sandbox_home_dir}/executable"
  mv "${sandbox_collections_dir}" "${sandbox_home_dir}/collections"
  firejail \
    --quiet \
    --noprofile \
    --net=none \
    --private="${sandbox_home_dir}" \
    --restrict-namespaces \
    /root/executable >>"${stdout_file}" 2>>"${stderr_file}" &
  local pid=$!
  echo "${pid} ${sandbox_home_dir} ${stdout_file} ${stderr_file}"
}
daemon_collector._get_executables() {
  local plugin_executables=()
  local plugins="${1}"
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
  local executable_paths=("$@")
  local process_pids=()
  local home_dirs=()
  local stdout_files=()
  local stderr_files=()
  local soloskilled=false
  for executable_path in "${executable_paths[@]}"; do
    local run_output="$(daemon_collector._run "${scrubbed_copy}" "${executable_path}")"
    local process_pid="$(echo "${run_output}" | xargs | cut -d' ' -f1)"
    local home_dir="$(echo "${run_output}" | xargs | cut -d' ' -f2)"
    local stdout_file="$(echo "${run_output}" | xargs | cut -d' ' -f3)"
    local stderr_file="$(echo "${run_output}" | xargs | cut -d' ' -f4)"
    if [[ -f ${stdout_file} ]] && grep -q "^SOLOS_KILL" "${stdout_file}" >/dev/null 2>/dev/null; then
      soloskilled=true
    fi
    if [[ -f ${stderr_file} ]] && grep -q "^SOLOS_KILL" "${stderr_file}" >/dev/null 2>/dev/null; then
      soloskilled=true
    fi
    if [[ -f ${stderr_file} ]]; then
      cat "${stderr_file}" >&2
    fi
    process_pids+=("${process_pid}")
    home_dirs+=("${home_dir}")
    stdout_files+=("${stdout_file}")
    stderr_files+=("${stderr_file}")
  done

  local failures=0
  local collections_dirs=()
  local i=0
  for process_pid in "${process_pids[@]}"; do
    wait "${process_pid}"
    local exit_status=$?
    if [[ ${exit_status} -ne 0 ]]; then
      daemon_collector.log_error "Plugin malfunction - the collector at ${executable_path} exited with status ${exit_status}"
      failures=$((failures + 1))
      # Must maintain order
      collections_dirs+=("-")
    else
      local collections_dir="${home_dirs[${i}]}/collections"
      if [[ ! -d ${collections_dir} ]]; then
        daemon_collector.log_warn "Plugin malfunction - the collector at ${executable_path} must have deleted its collections directory."
        # Must maintain order
        collections_dirs+=("-")
      else
        collections_dirs+=("${collections_dir}")
      fi
    fi
  done
  local return_code=0
  if [[ ${failures} -gt 0 ]]; then
    daemon_collector.log_error "Plugin malfunction - there were ${failures} plugin malfunctions."
    return_code=1
  fi
  if [[ ${soloskilled} = true ]]; then
    daemon_collector.log_error "Plugin malfunction - the collector was killed by a "SOLOS_KILLED" output line."
    return_code=151
  fi
  for collections_dir in "${collections_dirs[@]}"; do
    echo "${collections_dir}"
  done
  return ${return_code}
}
daemon_collector._mv_to_shared() {
  local name="${1}"
  local collections_path="${2}"
  local shared_path="${3}"
  local files="$(find "${collections_path}" -type f | xargs)"
  for file in ${files}; do
    local dirpath="$(dirname "${file}")"
    local shared_relative_dir="${dirpath#${collections_path}}"
    local shared_abs_path="${shared_path}/${shared_relative_dir}"
    mkdir -p "${shared_abs_path}"
    mv "${file}" "${shared_abs_path}/${name}"
  done
}

daemon_collector.main() {
  # The scrubbed copy is everything in the user's ~/.solos directory devoid of
  # 1) potentially sensitive files based on a blacklist of extensions (it's a bit aggressive. might need changes)
  # 2) .gitignored files/folders
  # 3) secrets found in any .env* files, ~/.solos/secrets dirs, or ~/.solos/projects/<...>/secrets dirs
  local scrubbed_copy="${1}"

  # Were it not for security concerns,
  # we'd simply mount a shared folder to each collector's firejailed process and let them write their output there,
  # relying on the due dilligence of plugin authors to avoid file collisions.
  # But, for max sandboxing, we don't want collectors to gain the ability to "communicate" across plugins via such shared folders.
  # So instead, after a collector runs, we'll rename all files in their collections dir to use a unique prefix.
  # Then, recursively copy each collector's collection dir to a single new folder that our processors can use.
  # Collisions aren't possible due to the prefixes. But categorical folders are still used to keep things organized and to ensure maximum
  # backwards compatibility with existing processors.
  #
  # Extra unrelated note: while I don't normally endorse engineering for speculative use-cases, I believe the SolOS plugin
  # design will almost certain end up with a permission system, even if it's just trusted/untrusted. That's why we need full sandboxing
  # not just between a collector and our system, but also a collector and other collectors. If from day we only add "trusted" plugins,
  # introducing the concept of "untrusted" plugins should not result in a major version bump.

  # Get the executables and names of internal/installed collectors.
  local names=()
  local precheck_executables=("$(daemon_collector._get_executables "$(daemon_shared.get_precheck_plugins)")")
  for precheck_executable in "${precheck_executables[@]}"; do
    names+=("precheck-$(basename "$(dirname "${precheck_executable}")")")
  done
  local internal_executables=("$(daemon_collector._get_executables "$(daemon_shared.get_internal_plugins)")")
  for internal_executable in "${internal_executables[@]}"; do
    names+=("internal-$(basename "$(dirname "${internal_executable}")")")
  done
  local installed_executables=("$(daemon_collector._get_executables "$(daemon_shared.get_installed_plugins)")")
  for installed_executable in "${installed_executables[@]}"; do
    names+=("installed-$(basename "$(dirname "${installed_executable}")")")
  done

  # Internal plugins should never fail since installed plugins might depend on state that internal plugins provides.
  # Necessary pre-requisite for pushing more and more key functionality into internal plugins rather than bloating
  # SolOS with tons of baked-features.
  local tmp_collectors_outpaths_file="$(mktemp)"
  if ! daemon_collector._execute "${scrubbed_copy}" "${precheck_executables[@]}" >>"${tmp_collectors_outpaths_file}"; then
    return 1
  fi
  if ! daemon_collector._execute "${scrubbed_copy}" "${internal_executables[@]}" >>"${tmp_collectors_outpaths_file}"; then
    return 1
  fi
  # Installed plugins can fail since they're not guaranteed to be well-behaved and we don't want one shitty
  # plugin to prevent the rest from running.
  daemon_collector._execute "${scrubbed_copy}" "${installed_executables[@]}" >>"${tmp_collectors_outpaths_file}"

  local collectors_outpaths=()
  while read -r line; do
    collectors_outpaths+=("$(echo "${line}" | xargs)")
  done <"${tmp_collectors_outpaths_file}"

  # Time to build up a single shared collections directory.
  local merged_collections_dir="$(mktemp -d)"
  local i=0
  for collections_dir in "${collectors_outpaths[@]}"; do
    if [[ ${collections_dir} = "-" ]]; then
      i=$((i + 1))
      continue
    fi
    local name="${names[${i}]}"
    daemon_collector._mv_to_shared "${name}" "${collections_dir}" "${merged_collections_dir}"
    i=$((i + 1))
  done

  echo "${merged_collections_dir}"
}
