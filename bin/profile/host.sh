#!/usr/bin/env bash

set -m

host() {
  local done_file="${HOME}/.solos/pipes/host.done"
  local command_file="${HOME}/.solos/pipes/host.command"
  local stdout_file="${HOME}/.solos/pipes/host.stdout"
  local stderr_file="${HOME}/.solos/pipes/host.stderr"
  local cmd=''"${*}"''
  rm -f "${stdout_file}"
  echo "" >"${done_file}"
  echo ''"${cmd}"'' >"${command_file}"
  while [[ ! -f "${stdout_file}" ]]; do
    sleep 0.1
  done
  cat "${stdout_file}"
  cat "${stderr_file}" || echo "" >&2
  rm -f "${done_file}" "${command_file}" "${stdout_file}" "${stderr_file}"
}
