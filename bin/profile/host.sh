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
  echo "" >"${stderr_file}"
  echo "" >"${stdout_file}"
  echo ''"${cmd}"'' >"${command_file}"
  while [[ $(cat "${done_file}") != "DONE" ]]; do
    sleep 0.1
  done
  # trim empty trailing newline
  stdout="$(cat "${stdout_file}")"
  stderr="$(cat "${stderr_file}")"
  rm -f "${done_file}" "${command_file}" "${stdout_file}" "${stderr_file}"
  if [[ -n ${stdout} ]]; then
    echo "${stdout}"
  fi
  if [[ -n ${stderr} ]]; then
    echo "${stderr}" >&2
  fi
}
