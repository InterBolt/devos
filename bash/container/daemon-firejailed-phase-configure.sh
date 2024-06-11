#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_phase_configure.log_info() {
  local message="(PHASE:CONFIGURE) ${1}"
  shift
  log.info "${message}" "$@"
}
daemon_phase_configure.log_error() {
  local message="(PHASE:CONFIGURE) ${1}"
  shift
  log.error "${message}" "$@"
}
daemon_phase_configure.log_warn() {
  local message="(PHASE:CONFIGURE) ${1}"
  shift
  log.warn "${message}" "$@"
}
daemon_phase_configure.exec() {
  local stdout_file="${1}"
  local stderr_file="${2}"
  shift 2
  daemon_shared.firejail \
    "--" \
    "${@}" \
    "--" \
    --net=none \
    "--" \
    "--phase-configure"
}
daemon_phase_configure.main() {
  local plugins="$@"
  local plugin_names=()
  for plugin in "${plugins[@]}"; do
    if [[ ${plugin} =~ ^/root/.solos/src/plugins ]]; then
      plugin_names+=("internal-$(basename "${plugin}")")
    elif [[ ${plugin} =~ ^/root/.solos/src ]]; then
      plugin_names+=("precheck-$(basename "${plugin}")")
    else
      plugin_names+=("installed-$(basename "$(dirname "${plugin}")")")
    fi
  done

  local stdout_file="$(mktemp)"
  local stderr_file="$(mktemp)"
  local stashed_firejailed_home_dirs="$(mktemp)"
  daemon_phase_configure.exec \
    "${stdout_file}" "${stderr_file}" \
    "${plugins[@]}" >>"${stashed_firejailed_home_dirs}"
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
  local prefixed_stderr_file="$(mktemp)"
  local prefixed_stdout_file="$(mktemp)"
  local i=0
  for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    while IFS= read -r line; do
      if [[ ${line} =~ ^firejail-${i}: ]]; then
        line="${line//firejail-${i}: /}"
        echo "(${plugin_name}) ${line}" >>"${prefixed_stderr_file}"
      fi
    done <"${stderr_file}"
    while IFS= read -r line; do
      if [[ ${line} =~ ^firejail-${i}: ]]; then
        line="${line//firejail-${i}: /}"
        echo "(${plugin_name}) ${line}" >>"${prefixed_stdout_file}"
      fi
    done <"${stdout_file}"
    if [[ ${firejailed_home_dir} != "-" ]]; then
      cp -r "${firejailed_home_dir}/solos.json" "${merged_configure_dir}/${plugin_name}-solos.json"
    fi
    i=$((i + 1))
  done
  echo "${prefixed_stdout_file} ${prefixed_stderr_file} ${merged_configure_dir}"
}
