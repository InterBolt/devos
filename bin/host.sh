#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

. "${HOME}/.solos/src/shared/lib.sh" || exit 1

host__repo_dir="${HOME}/.solos/src"
host__data_dir="$(lib.data_dir_path)"
host__store_dir="${host__data_dir}/store"
host__suppress_docker_output="${SUPPRESS_DOCKER_OUTPUT:-true}"
host__last_container_hash="$(cat "$(lib.last_container_hash_path)" 2>/dev/null || echo "")"
host__curr_container_hash="$(git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo "")"
if [[ ${host__suppress_docker_output} = true ]] && [[ -z ${host__curr_container_hash} ]] && [[ ${host__curr_container_hash} != "${host__last_container_hash}" ]]; then
  host__suppress_docker_output=false
fi

host.error_press_enter() {
  echo "Host: press enter to exit..."
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
    echo "Internal host error: a file called .solos was detected in your home directory." >&2
    host.error_press_enter
  fi
  if [[ ! -d ${host__store_dir} ]]; then
    mkdir -p "${host__store_dir}"
    echo "Host: created the store directory at ${host__store_dir}" >&2
  fi
  echo "${HOME}" >"${host__store_dir}/users_home_dir"
  local extra_flags=""
  if [[ ${host__suppress_docker_output} = true ]]; then
    extra_flags="-q "
  fi
  if ! docker build "${extra_flags}"-t "solos:${host__curr_container_hash}" "-f" "${host__repo_dir}/Dockerfile" .; then
    echo "Internal host error: failed to build the docker image." >&2
    host.error_press_enter
  fi
  echo "${host__curr_container_hash}" >"${host__last_container_hash}"
  echo "Host: built the container with hash ${host__curr_container_hash}" >&2
  if ! docker run -d --name "${host__curr_container_hash}" --network host --pid host --privileged -v "/var/run/docker.sock:/var/run/docker.sock" -v "${HOME}/.solos:/root/.solos" "solos:${host__curr_container_hash}" >/dev/null; then
    echo "Internal host error: failed to run the docker container." >&2
    host.error_press_enter
  fi
  echo "Host: container is running with hash ${host__curr_container_hash}" >&2
  while ! docker exec -w "/root/.solos" "${host__curr_container_hash}" echo "" >/dev/null 2>&1; do
    sleep .2
  done
  echo "Host: container is ready." >&2
  docker exec \
    -w "/root/.solos" "${host__curr_container_hash}" \
    /bin/bash -c 'nohup "/root/.solos/src/daemon/bin.sh" >/dev/null 2>&1 &' >/dev/null
  echo "Host: started the daemon." >&2
}
host.shell() {
  if ! docker exec -w "/root/.solos" "${host__curr_container_hash}" echo "" >/dev/null 2>&1; then
    if ! host.build; then
      echo "Internal host error: failed to rebuild the SolOS container." >&2
      host.error_press_enter
    fi
  fi
  local bashrc_file="${1:-""}"
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "Internal host error: the supplied bashrc file at ${bashrc_file} does not exist." >&2
      host.error_press_enter
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    docker exec -w "/root/.solos" "${host__curr_container_hash}" /bin/bash --rcfile "${relative_bashrc_file}" -i
  else
    docker exec -w "/root/.solos" "${host__curr_container_hash}" /bin/bash -i
  fi
}
host.cmd() {
  if ! docker exec -w "/root/.solos" "${host__curr_container_hash}" echo "" >/dev/null 2>&1; then
    if ! host.build; then
      echo "Internal host error: failed to rebuild the SolOS container." >&2
      exit 1
    fi
  fi
  if docker exec -w "/root/.solos" "${host__curr_container_hash}" /bin/bash -c ''"${*}"''; then
    local checked_out_project="$(lib.checked_out_project)"
    local code_workspace_file="${HOME}/.solos/projects/${checked_out_project}/${checked_out_project}.code-workspace"
    if [[ -f ${code_workspace_file} ]]; then
      code "${code_workspace_file}"
    fi
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
