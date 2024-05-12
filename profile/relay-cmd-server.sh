#!/usr/bin/env bash

__relay_cmd_server__var__dir=".solos/relay"
__relay_cmd_server__var__command="${__relay_cmd_server__var__dir}/command"
__relay_cmd_server__var__stdout="${__relay_cmd_server__var__dir}/stdout"
__relay_cmd_server__var__stderr="${__relay_cmd_server__var__dir}/stderr"
__relay_cmd_server__var__done="${__relay_cmd_server__var__dir}/done"

__relay_cmd_server__fn__cleanup() {
  local ps_info="$(
    ps aux | grep "relay-cmd-server.sh" | grep -v "grep relay-cmd-server.sh" | grep -v "$$" |
      tr -s ' '
  )"
  local pids_previous="$(
    echo "${ps_info}" | cut -d' ' -f2 | xargs
  )"
  local process_statuses="$(
    echo "${ps_info}" | cut -d' ' -f8 | xargs
  )"
  if [ "${pids_previous}" ]; then
    local pid_index=0
    for pid in ${pids_previous}; do
      local status="$(echo "${process_statuses}" | cut -d' ' -f"$((pid_index + 1))")"
      if [[ ${pid} = $$ ]]; then
        continue
      fi
      if [[ $(ps aux | grep "${pid}" | grep -v "grep ${pid}" | wc -l) -gt 0 ]]; then
        kill -9 "${pid}" >/dev/null || exit 1
      fi
      pid_index=$((pid_index + 1))
    done
  fi
}

__relay_cmd_server__fn__listen() {
  mkdir -p "${HOME}/${__relay_cmd_server__var__dir}"
  local done_file="${HOME}/${__relay_cmd_server__var__done}"
  local stdout_file="${HOME}/${__relay_cmd_server__var__stdout}"
  local stderr_file="${HOME}/${__relay_cmd_server__var__stderr}"
  local command_file="${HOME}/${__relay_cmd_server__var__command}"
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

__relay_cmd_server__fn__cleanup
__relay_cmd_server__fn__listen &
