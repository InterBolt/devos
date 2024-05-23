#!/usr/bin/env bash

__backgound__fn__relay() {
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
      command="$(cat "${command_file}" 2>/dev/null || echo "" | sed "s/\/root\//\$HOME\//g")"
    fi
    if [[ -n ${command} ]]; then
      local return_code=0
      if ! eval ''"${command}"'' 1>"${stdout_file}" 2>"${stderr_file}"; then
        return_code=$?
      fi
      echo "DONE:${return_code}" >"${done_file}"
    fi
    sleep .2
  done
}

__backgound__fn__relay &
