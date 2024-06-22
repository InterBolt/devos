#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

. "${HOME}/.solos/repo/shared/lib.sh" || exit 1

host__repo_dir="${HOME}/.solos/repo"
host__data_dir="$(lib.data_dir_path)"
host__store_dir="${host__data_dir}/store"
host__suppress_output="${SUPPRESS_DOCKER_OUTPUT:-true}"
host__last_container_hash="$(cat "$(lib.last_container_hash_path)" 2>/dev/null || echo "")"
host__curr_container_hash="$(git -C "${HOME}/.solos/repo" rev-parse --short HEAD | cut -c1-7 || echo "")"
if [[ ${host__suppress_output} = true ]] && [[ -z ${host__curr_container_hash} ]] && [[ ${host__curr_container_hash} != "${host__last_container_hash}" ]]; then
  host__suppress_output=false
fi

host.error_press_enter() {
  echo "Host [bin]: press enter to exit..."
  read -r || exit 1
  exit 1
}
host.build() {
  if [[ ${host__suppress_output} = false ]]; then
    echo "Host [bin]: rebuilding the docker container." >&2
  fi
  local image_names=($(docker ps -a --format '{{.Image}}' | xargs))
  for image_name in "${image_names[@]}"; do
    if [[ ${image_name} = "solos:"* ]]; then
      if ! docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null; then
        echo "Host error [bin]: failed to stop the container with image name ${image_name}." >&2
        host.error_press_enter
      fi
      if ! docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null; then
        echo "Host error [bin]: failed to remove the container with image name ${image_name}." >&2
        host.error_press_enter
      fi
      if ! docker rmi "${image_name}" >/dev/null; then
        echo "Host error [bin]: failed to remove the image with image name ${image_name}." >&2
        host.error_press_enter
      fi
    fi
  done
  if [[ -f ${HOME}/.solos ]]; then
    echo "Host error [bin]: a file called .solos was detected in your home directory." >&2
    host.error_press_enter
  fi
  local shared_args="-t solos:${host__curr_container_hash} -f ${host__repo_dir}/Dockerfile ."
  local suppressed_args="-q"
  local args=""
  if [[ ${host__suppress_output} = true ]]; then
    args="${suppressed_args} ${shared_args}"
  else
    args="${shared_args}"
  fi
  if [[ ${host__suppress_output} = false ]]; then
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fi
  if ! echo "${args}" | xargs docker build >/dev/null; then
    echo "Host error [bin]: failed to build the docker image." >&2
    host.error_press_enter
  fi
  if [[ ${host__suppress_output} = false ]]; then
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fi
  if [[ ! -d ${host__store_dir} ]]; then
    mkdir -p "${host__store_dir}"
    echo "Host [bin]: created the store directory at ${host__store_dir}" >&2
  fi
  echo "${HOME}" >"${host__store_dir}/users_home_dir"
  echo "${host__curr_container_hash}" >"$(lib.last_container_hash_path)"
  echo "Host [bin]: built docker image - solos:${host__curr_container_hash}" >&2
  if ! docker run -d --name "${host__curr_container_hash}" --network host --pid host --privileged -v "/var/run/docker.sock:/var/run/docker.sock" -v "${HOME}/.solos:/root/.solos" "solos:${host__curr_container_hash}" >/dev/null; then
    echo "Host error [bin]: failed to run the docker container." >&2
    host.error_press_enter
  fi
  echo "Host [bin]: container is running - solos" >&2
  while ! docker exec "${host__curr_container_hash}" echo "" >/dev/null 2>&1; do
    sleep .2
  done
  echo "Host [bin]: container is ready." >&2
  docker exec \
    "${host__curr_container_hash}" \
    /bin/bash -c 'nohup "/root/.solos/repo/daemon/daemon.sh" >/dev/null 2>&1 &' >/dev/null
  echo "Host [bin]: started the daemon." >&2
}
host.shell() {
  if ! docker exec "${host__curr_container_hash}" echo "" >/dev/null 2>&1; then
    if ! host.build; then
      echo "Host error [bin]: failed to rebuild the SolOS container." >&2
      host.error_press_enter
    fi
  fi
  local bashrc_file="${1:-""}"
  local mounted_dir="${HOME}/.solos"
  local working_dir="${2:-"${mounted_dir}"}"
  local container_working_directory="${working_dir/#$HOME//root}"
  if [[ ${container_working_directory} != "/root/.solos"* ]]; then
    container_working_directory="/root/.solos"
  fi
  {
    while true; do
      mkdir -p "${HOME}/.solos/data/store"
      rm -f "${HOME}/.solos/data/store/active_shell"
      echo "$(date +%s)" >"${HOME}/.solos/data/store/active_shell"
      sleep 3
    done
  } &
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "Host error [bin]: the supplied bashrc file at ${bashrc_file} does not exist." >&2
      host.error_press_enter
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    if ! docker exec -it -w "${container_working_directory}" "${host__curr_container_hash}" /bin/bash --rcfile "${relative_bashrc_file}" -i; then
      echo "Host error [bin]: failed to start the shell with the supplied bashrc file." >&2
      host.error_press_enter
    fi
  elif ! docker exec -it -w "${container_working_directory}" "${host__curr_container_hash}" /bin/bash -i; then
    echo "Host error [bin]: failed to start the shell." >&2
    host.error_press_enter
  fi
}
host.cmd() {
  if ! docker exec "${host__curr_container_hash}" echo "" >/dev/null 2>&1; then
    if ! host.build; then
      echo "Host error [bin]: failed to rebuild the SolOS container." >&2
      exit 1
    fi
  fi
  if docker exec -it "${host__curr_container_hash}" /bin/bash -c ''"${*}"''; then
    local checked_out_project="$(lib.checked_out_project)"
    local code_workspace_file="${HOME}/.solos/projects/${checked_out_project}/.vscode/${checked_out_project}.code-workspace"
    if [[ -f ${code_workspace_file} ]]; then
      code "${code_workspace_file}"
    fi
  fi
}
host.main() {
  if [[ ${1} = "shell" ]]; then
    host.shell "${HOME}/.solos/rcfiles/.bashrc" "${PWD}"
    exit $?
  elif [[ ${1} = "shell-minimal" ]]; then
    host.shell
    exit $?
  else
    host.cmd "/root/.solos/repo/bin/container.sh" "${PWD}" "$@"
    exit $?
  fi
}

host.main "$@"
