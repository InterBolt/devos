#!/usr/bin/env bash

# This script is responsible for spawning background processes that our shell depends on.
# Feel free to define and start more by running `your_fn &`.

__shell_backgound__fn__host_command_relay() {
  # Let the caller manage the filesystem.
  local relay_dir="${HOME}/.solos/.relay"
  local stdout_file="${relay_dir}/stdout"
  local stderr_file="${relay_dir}/stderr"
  local command_file="${relay_dir}/command"
  local done_file="${relay_dir}/done"
  while true; do
    local command=""
    if [[ -f "${command_file}" ]]; then
      command="$(cat "${command_file}" 2>/dev/null || echo "" | sed "s/\/root\//\$HOME\//g")"
    fi
    if [[ -n ${command} ]]; then
      local return_code=0
      rm -f "${stdout_file}" "${stderr_file}"
      eval ''"${command}"'' >"${stdout_file}" 2>"${stderr_file}"
      return_code=$?
      rm -f "${command_file}"
      echo "DONE:${return_code}" >"${done_file}"
    fi
    sleep .1
  done
}

__shell_backgound__fn__host_command_relay &
