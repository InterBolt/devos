#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_phase_collection.log_info() {
  local message="(PHASE:COLLECTION) ${1}"
  shift
  log.info "${message}" "$@"
}
daemon_phase_collection.log_error() {
  local message="(PHASE:COLLECTION) ${1}"
  shift
  log.error "${message}" "$@"
}
daemon_phase_collection.log_warn() {
  local message="(PHASE:COLLECTION) ${1}"
  shift
  log.warn "${message}" "$@"
}
daemon_phase_collection.exec() {
  local scrubbed_dir="${1}"
  local merged_download_dir="${2}"
  local stdout_file="${3}"
  local stderr_file="${4}"
  shift 4
  daemon_shared.firejail \
    "${scrubbed_dir}" "/.solos" "ro" \
    "${merged_download_dir}" "/download" "ro" \
    "$(mktemp -d)" "/collection" "rw" \
    "--" \
    "${@}" \
    "--" \
    --net=none \
    "--" \
    "--phase-collection"
}
daemon_phase_collection.main() {
  local merged_configure_dir="${1}"
  local scrubbed_dir="${2}"
  local merged_download_dir="${3}"
  shift 3
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
  daemon_phase_collection.exec \
    "${merged_configure_dir}" "${scrubbed_dir}" "${merged_download_dir}" "${stdout_file}" "${stderr_file}" \
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

  local merged_collection_dir="$(mktemp -d)"
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
      daemon_shared.merged_namespaced_fs \
        "${plugin_name}" \
        "${firejailed_home_dir}/collection" \
        "${merged_collection_dir}"
    fi
    i=$((i + 1))
  done

  echo "${prefixed_stdout_file} ${prefixed_stderr_file} ${merged_collection_dir}"
}
