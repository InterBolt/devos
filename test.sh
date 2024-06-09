#!/usr/bin/env bash

daemon_collector._firejail() {
  local executable_path="${1}"
  local tmp_home_dir="$(mktemp -d)"
  local tmp_collections_dir="$(mktemp -d)"
  local tmp_scrubbed_solos_dir="$(mktemp -d)"
  mv "${tmp_collections_dir}" "${tmp_home_dir}/collections"
  mv "${tmp_scrubbed_solos_dir}" "${tmp_home_dir}/.solos"
  cp -a "${executable_path}" "${tmp_home_dir}/collector"
  local tmp_stdout="$(mktemp)"
  local tmp_stderr="$(mktemp)"
  local pids=()
  firejail \
    --quiet \
    --noprofile \
    --net=none \
    --private="${tmp_home_dir}" \
    --restrict-namespaces \
    /root/collector >>"${tmp_stdout}" 2>>"${tmp_stderr}" &
  pids=("${pids[@]}" $!)
  firejail \
    --quiet \
    --noprofile \
    --net=none \
    --private="${tmp_home_dir}" \
    --restrict-namespaces \
    /root/collector >>"${tmp_stdout}" 2>>"${tmp_stderr}" &
  pids=("${pids[@]}" $!)

  for pid in "${pids[@]}"; do
    wait "${pid}"
    echo "PID ${pid} exited with status $?"
  done

  cat "${tmp_stdout}"
  # if cat "${tmp_stdout}" | grep -E "^FAILED:"; then
  #   echo "Unexpected error: precheck plugin failed to confirm firejail assumptions for the collector executable."
  #   exit 1
  # fi
}

daemon_collector._firejail "/root/.solos/src/plugins/solos-precheck/collector"
