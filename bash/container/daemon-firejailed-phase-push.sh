#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/container/daemon-shared.sh" || exit 1

daemon_phase_push.log_info() {
  local message="(PHASE:PUSH) ${1}"
  shift
  log.info "${message}" "$@"
}
daemon_phase_push.log_error() {
  local message="(PHASE:PUSH) ${1}"
  shift
  log.error "${message}" "$@"
}
daemon_phase_push.log_warn() {
  local message="(PHASE:PUSH) ${1}"
  shift
  log.warn "${message}" "$@"
}

daemon_phase_push.exec() {
  local merged_process_dir="${1}"
  local stdout_file="${2}"
  local stderr_file="${3}"
  shift 3
  daemon_shared.firejail \
    "${merged_process_dir}" "/processed" "ro" \
    "$(mktemp -d)" "/pushed" "rw" \
    "--" \
    "${@}" \
    "--" \
    "--" \
    "--phase-push"
}
daemon_phase_push.main() {
  local merged_configure_dir="${1}"
  local merged_process_dir="${2}"
  shift 2
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
  daemon_phase_push.exec \
    "${merged_process_dir}" "${stdout_file}" "${stderr_file}" \
    "${plugins[@]}" >>"${stashed_firejailed_home_dirs}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi

  local firejailed_home_dirs=()
  while read -r line; do
    firejailed_home_dirs+=("$(echo "${line}" | xargs)")
  done <"${stashed_firejailed_home_dirs}"

  local merged_pushed_dir="$(mktemp -d)"
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
        "${firejailed_home_dir}/pushed" \
        "${merged_pushed_dir}"
    fi
    i=$((i + 1))
  done

  echo "${prefixed_stdout_file} ${prefixed_stderr_file} ${merged_pushed_dir}"
}
