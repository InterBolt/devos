#!/usr/bin/env bash

__relay_cmd_server__fn__listen() {
  local command=".solos/.relay.command"
  local stdout=".solos/.relay.stdout"
  local stderr=".solos/.relay.stderr"
  local done=".solos/.relay.done"

  mkdir -p "${HOME}/${dir}"
  local done_file="${HOME}/${done}"
  local stdout_file="${HOME}/${stdout}"
  local stderr_file="${HOME}/${stderr}"
  local command_file="${HOME}/${command}"
  rm -f "${stdout_file}" "${stderr_file}" "${command_file}" "${done_file}"
  touch "${stdout_file}" "${stderr_file}" "${command_file}" "${done_file}"
  while true; do
    local command=""
    if [[ -f "${command_file}" ]]; then
      command="$(cat "${command_file}" | sed "s/\/root\//\$HOME\//g")"
    fi
    if [[ -n ${command} ]]; then
      local profile="${HOME}/.bash_profile"
      if [[ ! -f "${profile}" ]]; then
        profile="${HOME}/.bashrc"
        if {[ ! -f "${profile}" ]}; then
          profile=""
        fi
      fi
      if [ "${profile}" ]; then
        eval "${command}" 1>"${stdout_file}" 2>"${stderr_file}"
        echo "DONE" >"${done_file}"
      else
        eval "${command}" 1>"${stdout_file}" 2>"${stderr_file}"
        echo "DONE" >"${done_file}"
      fi
    fi
    sleep .2
  done
}

__relay_cmd_server__fn__listen &
