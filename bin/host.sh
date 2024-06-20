#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1

host__repo_dir="${HOME}/.solos/src"
host__data_dir="$(lib.data_dir_path)"
host__store_dir="${host__data_dir}/store"
host__last_container_hash="$(lib.last_container_hash)"
host__user_bashrc_path="${HOME}/.solos/rcfiles/.bashrc"
host__use_minimal_shell=false
host__use_full_shell=false
host__is_cmd=true

export DOCKER_CLI_HINTS=false

host.error_press_enter() {
  echo "Press enter to exit..."
  read -r || exit 1
  exit 1
}
host.container_hash() {
  git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
host.destroy() {
  local image_names="$(docker ps -a --format '{{.Image}}' | xargs)"
  for image_name in ${image_names}; do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
    fi
  done
}
host.test() {
  local container_hash="${1}"
  shift
  if ! docker exec -w "/root/.solos" "${container_hash}" echo ""; then
    return 1
  fi
  return 0
}
host.launch_daemon() {
  local container_hash="${1}"
  shift
  docker exec \
    -w "/root/.solos" "${container_hash}" \
    /bin/bash -c 'nohup "/root/.solos/src/daemon/bin.sh" >/dev/null 2>&1 &'
}
host.exec_shell() {
  local container_hash="${1}"
  shift
  local bashrc_file="${1:-""}"
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "The supplied bashrc file at ${bashrc_file} does not exist." >&2
      host.error_press_enter
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    docker exec -w "/root/.solos" "${container_hash}" /bin/bash --rcfile "${relative_bashrc_file}" -i
  else
    docker exec -w "/root/.solos" "${container_hash}" /bin/bash -i
  fi
}
host.exec_command() {
  local container_hash="${1}"
  shift
  docker exec -w "/root/.solos" "${container_hash}" /bin/bash -c ''"${*}"''
}
host.build_and_run() {
  if [[ -f ${HOME}/.solos ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    host.error_press_enter
  fi
  if [[ ! -d ${host__store_dir} ]]; then
    mkdir -p "${host__store_dir}"
    echo "Created the store directory at ${host__store_dir}"
  fi
  echo "${HOME}" >"${host__store_dir}/users_home_dir"
  local prev_container_hash="$(cat "${host__last_container_hash}" 2>/dev/null || echo "")"
  local container_hash="$(host.container_hash)"
  local extra_flags=""
  if [[ ${prev_container_hash} != "${container_hash}" ]]; then
    extra_flags="-q"
  fi
  if ! docker build "${extra_flags}" -t "solos:${hash}" -f "${host__repo_dir}/Dockerfile" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    host.error_press_enter
  fi
  echo "${container_hash}" >"${host__last_container_hash}"
  docker run --name "${container_hash}" \
    --network host \
    --pid host \
    --privileged \
    -d \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${HOME}/.solos:/root/.solos" \
    "solos:${container_hash}"
  while ! host.test "${container_hash}"; do
    sleep .2
  done
  host.launch_daemon "${container_hash}"
}
host.rebuild() {
  echo -e "\033[0;34mRebuilding the container...\033[0m"
  if ! host.destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    host.error_press_enter
  fi
  if ! host.build_and_run; then
    echo "Unexpected error: failed to build and run the container." >&2
    host.error_press_enter
  fi
}
host.shell() {
  local container_hash="$(host.container_hash)"
  if host.test "${container_hash}"; then
    host.exec_shell "${container_hash}" "$@"
    return 0
  fi
  if host.rebuild; then
    host.exec_shell "${container_hash}" "$@"
  else
    echo "Unexpected error: failed to launch shell from container." >&2
    host.error_press_enter
  fi
}
host.cmd() {
  local container_hash="$(host.container_hash)"
  if host.test "${container_hash}"; then
    host.exec_command "${container_hash}" "$@"
    return 0
  fi
  if host.rebuild; then
    local tmp_stdout_file="$(mktemp)"
    if host.exec_command "${container_hash}" "$@" >"${tmp_stdout_file}"; then
      local code_workspace_file="$(tail -n 1 "${tmp_stdout_file}" | xargs)"
      if [[ -z ${code_workspace_file} ]]; then
        echo "Unexpected error: failed to determine the code workspace file." >&2
        exit 1
      fi
      if [[ ! -f ${HOME}/${code_workspace_file} ]]; then
        echo "Unexpected error: the code workspace file does not exist." >&2
        exit 1
      fi
      code "${HOME}/${code_workspace_file}"
    fi
  else
    echo "Unexpected error: failed to rebuild the SolOS container." >&2
    exit 1
  fi
}
host.main() {
  if [[ ${1} = "shell" ]]; then
    host.shell
    exit $?
  elif [[ ${1} = "shell-minimal" ]]; then
    host.shell "${host__user_bashrc_path}"
    exit $?
  else
    host.cmd "/root/.solos/src/bin/container.sh" "$@"
    exit $?
  fi
}

host.main "$@"
