#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

. "${HOME}/.solos/repo/src/shared/lib.universal.sh" || exit 1

host__repo_dir="${HOME}/.solos/repo"
host__data_dir="$(lib.data_dir_path)"
host__store_dir="${host__data_dir}/store"
host__hide_log_output=false
host__cli_data_dir="${host__data_dir}/cli"
host__log_file="${host__cli_data_dir}/master.log"
host__force_rebuild="${SUPPRESS_DOCKER_OUTPUT:-true}"
host__last_src_hash="$(cat "$(lib.last_container_hash_path)" 2>/dev/null || echo "")"
host__curr_src_hash="$(git -C "${HOME}/.solos/repo" rev-parse --short HEAD | cut -c1-7 || echo "")"
if [[ ${host__force_rebuild} = true ]] && [[ ${host__curr_src_hash} != "${host__last_src_hash}" ]]; then
  host__force_rebuild=false
fi
if [[ ${2} = "ide" ]]; then
  host__hide_log_output=true
fi

mkdir -p "${host__cli_data_dir}"

host.log_info() {
  local msg="(CLI:HOST) ${1}"
  echo "INFO ${msg}" >>"${host__log_file}"
  if [[ ${host__hide_log_output} = false ]]; then
    echo -e "\033[1;32mINFO \033[0m${msg}" >&2
  fi
}
host.log_warn() {
  local msg="(CLI:HOST) ${1}"
  echo "WARN ${msg}" >>"${host__log_file}"
  if [[ ${host__hide_log_output} = false ]]; then
    echo -e "\033[1;33mINFO \033[0m${msg}" >&2
  fi
}
host.log_error() {
  local msg="(CLI:HOST) ${1}"
  echo "ERROR ${msg}" >>"${host__log_file}"
  if [[ ${host__hide_log_output} = false ]]; then
    echo -e "\033[1;31mERROR \033[0m${msg}" >&2
  fi
}
host.build_image() {
  local dockerfile_path="${1}"
  local docker_image_name="${2}"
  local shared_args="-t ${docker_image_name} -f ${dockerfile_path} ."
  local suppressed_args="-q"
  local unsuppressed_args="--no-cache"
  local args=""
  if [[ ${host__force_rebuild} = true ]]; then
    args="${suppressed_args} ${shared_args}"
  else
    args="${unsuppressed_args} ${shared_args}"
  fi
  if [[ ${host__force_rebuild} = false ]]; then
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fi
  if ! echo "${args}" | xargs docker build >/dev/null; then
    host.log_error "Failed to build the docker image: ${docker_image_name}."
    lib.enter_to_exit
  fi
  if [[ ${host__force_rebuild} = false ]]; then
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fi
}
host.build() {
  if [[ ${host__force_rebuild} = false ]]; then
    host.log_info "Rebuilding the docker environment."
  fi
  local image_names=($(docker ps -a --format '{{.Image}}' | xargs))
  for image_name in "${image_names[@]}"; do
    if [[ ${image_name} = "solos:"* ]] || [[ ${image_name} = "solos-project:"* ]]; then
      if ! docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null; then
        host.log_error "Failed to stop the container with image name ${image_name}."
        lib.enter_to_exit
      fi
      if ! docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null; then
        host.log_error "Failed to remove the container with image name ${image_name}."
        lib.enter_to_exit
      fi
      if ! docker rmi "${image_name}" >/dev/null; then
        host.log_error "Failed to remove the image with image name ${image_name}."
        lib.enter_to_exit
      fi
    fi
  done
  if [[ -f ${HOME}/.solos ]]; then
    host.log_error "A file called .solos was detected in your home directory."
    lib.enter_to_exit
  fi
  local checked_out_project="$(lib.checked_out_project)"
  local docker_project_image="solos-project:${checked_out_project}"
  local default_project_dockerfile="${host__repo_dir}/src/Dockerfile.project"
  local checked_out_project_dockerfile="${HOME}/.solos/projects/${checked_out_project}/Dockerfile"
  local project_dockerfile=""
  if [[ -f ${checked_out_project_dockerfile} ]]; then
    project_dockerfile="${checked_out_project_dockerfile}"
  elif [[ -f ${default_project_dockerfile} ]]; then
    project_dockerfile="${default_project_dockerfile}"
  else
    host.log_error "Failed to find a Dockerfile for the project."
    lib.enter_to_exit
  fi
  local project_dockerfile_contents="$(cat "${project_dockerfile}")"
  local project_dockerfile_first_line="$(
    echo "${project_dockerfile_contents}" | grep -vE '^\s*#' | grep -vE '^\s*$' | head -n 1 | xargs
  )"
  if [[ ${project_dockerfile_first_line} != 'FROM solos:latest' ]]; then
    host.log_error "User error: SolOS expects the first statement in ${project_dockerfile} to be: \`FROM solos:latest\`."
    host.log_warn "Explanation: SolOS scripts depend on the solos:latest base image to function properly."
    lib.enter_to_exit
  fi
  host.build_image "${host__repo_dir}/src/Dockerfile" "solos:latest"
  host.build_image "${project_dockerfile}" "${docker_project_image}"
  if [[ ! -d ${host__store_dir} ]]; then
    mkdir -p "${host__store_dir}"
    host.log_info "Created the store directory at ${host__store_dir}"
  fi
  echo "${HOME}" >"${host__store_dir}/users_home_dir"
  echo "${host__curr_src_hash}" >"$(lib.last_container_hash_path)"
  host.log_info "Built docker image - ${docker_project_image}"
  if ! docker run \
    -d \
    --name solos-project \
    --network host \
    --pid host \
    --privileged \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    -v "${HOME}/.solos:/root/.solos" \
    "${docker_project_image}" tail -f /dev/null >/dev/null; then
    host.log_error "Failed to run the docker container."
    lib.enter_to_exit
  fi
  host.log_info "Started container running: ${docker_project_image}"
  while ! docker exec solos-project echo "" >/dev/null 2>&1; do
    sleep .2
  done
  host.log_info "Confirmed container: ${docker_project_image}"
  docker exec solos-project \
    /bin/bash -c 'nohup "/root/.solos/repo/src/daemon/daemon.sh" >/dev/null 2>&1 &' >/dev/null
  host.log_info "Started the daemon."
}
host.shell() {
  if ! docker exec solos-project echo "" >/dev/null 2>&1; then
    if ! host.build; then
      host.log_error "Failed to rebuild the SolOS container."
      lib.enter_to_exit
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
      host.log_error "The supplied bashrc file at ${bashrc_file} does not exist."
      lib.enter_to_exit
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    if ! docker exec -it -w "${container_working_directory}" solos-project /bin/bash --rcfile "${relative_bashrc_file}" -i; then
      host.log_error "Failed to start the shell with the supplied bashrc file."
      lib.enter_to_exit
    fi
  elif ! docker exec -it -w "${container_working_directory}" solos-project /bin/bash -i; then
    host.log_error "Failed to start the shell."
    lib.enter_to_exit
  fi
}
host.cmd() {
  if ! docker exec solos-project echo "" >/dev/null 2>&1; then
    if ! host.build; then
      host.log_error "Failed to rebuild the SolOS container."
      exit 1
    fi
  fi
  local is_help=false
  if [[ ${2} = "--help" ]] || [[ ${2} = "-h" ]] || [[ ${2} = "help" ]]; then
    is_help=true
  fi
  if docker exec -it solos-project /bin/bash -c ''"${*}"''; then
    if [[ ${is_help} = true ]]; then
      exit 0
    fi
    local checked_out_project="$(lib.checked_out_project)"
    local code_workspace_file="${HOME}/.solos/projects/${checked_out_project}/.vscode/${checked_out_project}.code-workspace"
    if [[ -f ${code_workspace_file} ]]; then
      code "${code_workspace_file}"
    fi
  fi
}
host() {
  if [[ ${1} = "shell" ]]; then
    host.shell "${HOME}/.solos/rcfiles/.bashrc" "${PWD}"
    exit $?
  elif [[ ${1} = "shell-minimal" ]]; then
    host.shell
    exit $?
  else
    host.cmd "/root/.solos/repo/src/bin/container.sh" "$@"
    exit $?
  fi
}

host "$@"
