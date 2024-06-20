#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

. "${HOME}/.solos/src/shared/lib.sh" || exit 1

host__repo_dir="${HOME}/.solos/src"
host__data_dir="$(lib.data_dir_path)"
host__store_dir="${host__data_dir}/store"
host__suppress_output=true
host__last_container_hash="$(cat "$(lib.last_container_hash_path)" 2>/dev/null || echo "")"
host__curr_container_hash="$(git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo "")"
if [[ -z ${host__curr_container_hash} ]] && [[ ${host__curr_container_hash} != "${host__last_container_hash}" ]]; then
  host__suppress_output=false
fi

host.error_press_enter() {
  echo "Something went wrong. Press enter to exit..."
  read -r || exit 1
  exit 1
}
host.build() {
  echo -e "\033[0;34mRebuilding the container...\033[0m"
  local image_names="$(docker ps -a --format '{{.Image}}' | xargs)"
  for image_name in ${image_names}; do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
    fi
  done
  if [[ -f ${HOME}/.solos ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    host.error_press_enter
  fi
  if [[ ! -d ${host__store_dir} ]]; then
    mkdir -p "${host__store_dir}"
    echo "Created the store directory at ${host__store_dir}"
  fi
  echo "${HOME}" >"${host__store_dir}/users_home_dir"
  local extra_flags=""
  if [[ ${host__suppress_output} = true ]]; then
    extra_flags="-q"
  fi
  if ! docker build "${extra_flags}" -t "solos:${hash}" -f "${host__repo_dir}/Dockerfile" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    host.error_press_enter
  fi
  echo "${host__curr_container_hash}" >"${host__last_container_hash}"
  docker run \
    -d \
    --name "${host__curr_container_hash}" \
    --network host \
    --pid host \
    --privileged \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${HOME}/.solos:/root/.solos" \
    "solos:${host__curr_container_hash}"
  while ! docker exec -w "/root/.solos" "${host__curr_container_hash}" echo ""; do
    sleep .2
  done
  docker exec \
    -w "/root/.solos" "${host__curr_container_hash}" \
    /bin/bash -c 'nohup "/root/.solos/src/daemon/bin.sh" >/dev/null 2>&1 &'
}
host.shell() {
  if ! docker exec -w "/root/.solos" "${host__curr_container_hash}" echo ""; then
    if ! host.build; then
      echo "Unexpected error: failed to rebuild the SolOS container." >&2
      host.error_press_enter
    fi
  fi
  local bashrc_file="${1:-""}"
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "The supplied bashrc file at ${bashrc_file} does not exist." >&2
      host.error_press_enter
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    docker exec -w "/root/.solos" "${host__curr_container_hash}" /bin/bash --rcfile "${relative_bashrc_file}" -i
  else
    docker exec -w "/root/.solos" "${host__curr_container_hash}" /bin/bash -i
  fi
}
host.cmd() {
  if ! docker exec -w "/root/.solos" "${host__curr_container_hash}" echo ""; then
    if ! host.build; then
      echo "Unexpected error: failed to rebuild the SolOS container." >&2
      exit 1
    fi
  fi
  local tmp_stdout_file="$(mktemp)"
  if docker exec -w "/root/.solos" "${host__curr_container_hash}" /bin/bash -c ''"${*}"'' \
    >"${tmp_stdout_file}"; then
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
}
host.main() {
  if [[ ${1} = "shell" ]]; then
    host.shell "${HOME}/.solos/rcfiles/.bashrc"
    exit $?
  elif [[ ${1} = "shell-minimal" ]]; then
    host.shell
    exit $?
  else
    host.cmd "/root/.solos/src/bin/container.sh" "$@"
    exit $?
  fi
}

host.main "$@"
