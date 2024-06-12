#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_firejailed_phase_configure.log_info() {
  local message="(PHASE:CONFIGURE) ${1}"
  shift
  log.info "${message}" "$@"
}
daemon_firejailed_phase_configure.log_error() {
  local message="(PHASE:CONFIGURE) ${1}"
  shift
  log.error "${message}" "$@"
}
daemon_firejailed_phase_configure.log_warn() {
  local message="(PHASE:CONFIGURE) ${1}"
  shift
  log.warn "${message}" "$@"
}
daemon_firejailed_phase_configure.main() {
  local plugins=("${@}")
  local plugin_names=($(daemon_shared.plugin_paths_to_names "${plugins[@]}"))
  local raw_stdout_file="$(mktemp)"
  local raw_stderr_file="$(mktemp)"
  local stashed_firejailed_home_dirs="$(mktemp)"
  local firejail_options=("--net=none")
  daemon_shared.firejail \
    "--" \
    "${plugins[@]}" \
    "--" \
    "${firejail_options[@]}" \
    "--" \
    "--phase-configure" >>"${stashed_firejailed_home_dirs}"
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

  local merged_configure_dir="$(mktemp -d)"
  local decoded_stderr_file="$(mktemp)"
  local decoded_stdout_file="$(mktemp)"
  local i=0
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    daemon_shared.decode_dumped_output \
      "(${plugin_name})" \
      "${raw_stdout_file}" "${raw_stderr_file}" \
      "${decoded_stdout_file}" "${decoded_stderr_file}"
    if [[ ${firejailed_home_dir} != "-" ]]; then
      cp -r "${firejailed_home_dir}/solos.json" "${merged_configure_dir}/${plugin_name}-solos.json"
    fi
    i=$((i + 1))
  done
  echo "${decoded_stdout_file}"
  echo "${decoded_stderr_file}"
  echo "${merged_configure_dir}"
}
