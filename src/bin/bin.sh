#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

. "${HOME}/.solos/repo/src/shared/lib.universal.sh" || exit 1

host__repo_dir="${HOME}/.solos/repo"
host__data_dir="$(lib.data_dir_path)"
host__container_name="solos-project"
host__store_dir="${host__data_dir}/store"
host__hide_log_output=false
host__cli_data_dir="${host__data_dir}/cli"
host__daemon_data_dir="${host__data_dir}/cli"
host__log_file="${host__cli_data_dir}/master.log"
host__force_rebuild=false
host__curr_checked_out_project="$(lib.checked_out_project)"
host__last_built_project_file="${host__data_dir}/cli/last_built_project"
host__last_built_project="$(cat "${host__data_dir}/cli/last_built_project" 2>/dev/null || echo "")"

# The user should still be able to run commands even if a project has not been checked out.
# But when that's the case, we should always force a rebuild for consistency.
if [[ ${host__last_built_project} != "${host__curr_checked_out_project}" ]] || [[ -z ${host__curr_checked_out_project} ]]; then
  host__force_rebuild=true
fi

# If the status file for the daemon at $HOME/.solos/data/daemon/status exists and it's contents equal "UP"
# then we should force a rebuild. Rebuilding will nuke the daemon and start a new one.
# While we can still rely on the internal logic of the daemon to use some common sense for when to shut down,
# this will act as a failsafe for when the daemon is in a bad state.
if [[ -f "${host__daemon_data_dir}/status" ]]; then
  local daemon_status="$(cat "${host__daemon_data_dir}/status" | head -n 1 | xargs)"
  if [[ ${daemon_status} = "UP" ]]; then
    host__force_rebuild=true
  fi
fi

# When the container is not running, we should force a rebuild.
# We don't really care why.
if ! docker exec "${host__container_name}" echo "" >/dev/null 2>&1; then
  host__force_rebuild=true
fi

# When running via an integrated IDE terminal, it's a little cleaner to hide the log output.
# It's still written to a file for debugging purposes.
if [[ ${2} = "ide" ]]; then
  host__hide_log_output=true
fi

# Might as well initialize the cli's data directory.
mkdir -p "${host__cli_data_dir}"

# Logging functions. Can't rely on the shared logger since that's for
# the container environment only. It depends on gum, which is not available here.
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
    echo -e "\033[1;33mWARN \033[0m${msg}" >&2
  fi
}
host.log_error() {
  local msg="(CLI:HOST) ${1}"
  echo "ERROR ${msg}" >>"${host__log_file}"
  if [[ ${host__hide_log_output} = false ]]; then
    echo -e "\033[1;31mERROR \033[0m${msg}" >&2
  fi
}

# Make the build output pretty with lines and colors.
host.build_image() {
  local dockerfile_path="${1}"
  local docker_image_name="${2}"
  echo -e "\033[1;32mBuilding docker image: ${docker_image_name} from ${dockerfile_path}\033[0m" >&2
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  if ! docker build -t "${docker_image_name}" -f "${dockerfile_path}" . >/dev/null; then
    host.log_error "Failed to build the docker image: ${docker_image_name}."
    lib.enter_to_exit
  fi
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

# Wipe existing containers and images, build the base and project images, and start the container.
host.build() {
  # It's paranoid, but let's catch the crazy edge cases.
  if [[ -f ${HOME}/.solos ]]; then
    host.log_error "A file called .solos was detected in your home directory."
    lib.enter_to_exit
  fi

  # Stop containers and remove images related to SolOS.
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

  # Determine the docker image(s) to build.
  # When the user is running commands, we don't care if a project is checked out or not.
  # Therefore, we need to support building/running the base image only if no project is checked out.
  local docker_base_image="solos:latest"
  local docker_project_image="solos-project:${host__curr_checked_out_project}"
  local default_project_dockerfile="${host__repo_dir}/src/Dockerfile.project"
  local checked_out_project_dockerfile="${HOME}/.solos/projects/${host__curr_checked_out_project}/Dockerfile"
  local project_dockerfile=""
  if [[ -f ${checked_out_project_dockerfile} ]]; then
    project_dockerfile="${checked_out_project_dockerfile}"
  elif [[ -f ${default_project_dockerfile} ]]; then
    project_dockerfile="${default_project_dockerfile}"
  elif [[ -n ${host__curr_checked_out_project} ]]; then
    host.log_error "Failed to find a Dockerfile to build for the project: ${host__curr_checked_out_project}"
    host.log_warn "Explanation: SolOS expects a Dockerfile to exist at either ${default_project_dockerfile} or ${checked_out_project_dockerfile}"
    lib.enter_to_exit
  fi
  local docker_image_to_run="${docker_project_image}"
  if [[ -z ${host__curr_checked_out_project} ]]; then
    docker_image_to_run="${docker_base_image}"
  fi

  # If we're relying on either the internal project dockerfile, or the user's, we should ensure
  # that it extends the base image. SolOS depends on the packages that the base dockerfile installs.
  if [[ -n ${host__curr_checked_out_project} ]]; then
    local project_dockerfile_contents="$(cat "${project_dockerfile}")"
    local project_dockerfile_first_line="$(
      echo "${project_dockerfile_contents}" | grep -vE '^\s*#' | grep -vE '^\s*$' | head -n 1 | xargs
    )"
    if [[ ${project_dockerfile_first_line} != 'FROM '"${docker_base_image}"'' ]]; then
      host.log_error "User error: SolOS expects the first statement in ${project_dockerfile} to be: \`FROM solos:latest\`."
      host.log_warn "Explanation: SolOS scripts depend on the solos:latest base image to function properly."
      lib.enter_to_exit
    fi
  fi

  # Build the base image, and the project image if a project is checked out.
  host.build_image "${host__repo_dir}/src/Dockerfile" "${docker_base_image}"
  host.log_info "Built the base docker image - ${docker_base_image}"
  if [[ -n ${host__curr_checked_out_project} ]]; then
    host.build_image "${project_dockerfile}" "${docker_project_image}"
    host.log_info "Built the project docker image - ${docker_project_image}"
  else
    host.log_info "Will run SolOS using: ${docker_base_image}"
  fi

  # Save the user's home directory to the store directory.
  if [[ ! -d ${host__store_dir} ]]; then
    mkdir -p "${host__store_dir}"
  fi
  echo "${HOME}" >"${host__store_dir}/users_home_dir"
  host.log_info "Saved the user's home directory to the store directory."

  # Only overwrite the last built project file if a project is checked out.
  if [[ -n ${host__curr_checked_out_project} ]]; then
    echo "${host__curr_checked_out_project}" >"${host__last_built_project_file}"
  fi

  # Start the container. Remember, we'll use the project-specific image if a project is checked out
  # and the base image if no project is checked out. Both will work.
  if ! docker run \
    -d \
    --name "${host__container_name}" \
    --network host \
    --pid host \
    --privileged \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    -v "${HOME}/.solos:/root/.solos" \
    "${docker_project_image}" tail -f /dev/null >/dev/null; then
    host.log_error "Failed to run the docker container."
    lib.enter_to_exit
  fi
  host.log_info "Started the \`"${host__container_name}"\` container using image: ${docker_project_image}"
  while ! docker exec "${host__container_name}" echo "" >/dev/null 2>&1; do
    sleep .2
  done
  host.log_info "The SolOS container is ready."
}
host.shell() {
  # Only the command function is allowed to run without a checked out project.
  if [[ -z $(lib.checked_out_project) ]]; then
    host.log_error "No project found. Use \`solos <project_name>\` to check out a project."
    lib.enter_to_exit
  fi

  # Potentially rebuild the container.
  # Eg. when the user has checked out a new project.
  if [[ ${host__force_rebuild} = true ]]; then
    if ! host.build; then
      host.log_error "Failed to rebuild the SolOS container."
      lib.enter_to_exit
    fi
  fi

  local bashrc_file="${1:-""}"
  # When the user is trying to start a shell from somewhere outside the mounted volume directory,
  # it makes the most sense to force them into the mounted volume directory since anything outside
  # of it won't exist in the container environment.
  local mounted_volume_dir="${HOME}/.solos"
  local working_dir="${2:-"${mounted_volume_dir}"}"
  local container_working_directory="${working_dir/#$HOME//root}"
  if [[ ${container_working_directory} != "/root/.solos"* ]]; then
    container_working_directory="/root/.solos"
  fi

  # So long as the shell is running, we should periodically write to a file so that
  # future attempts to start a SolOS shell fail if this shell is already running.
  # We might revisit this but for now it makes certain components easier to reason about.
  # Eg. wtf do we do if multiple daemons are running?
  {
    while true; do
      mkdir -p "${host__cli_data_dir}"
      rm -f "${host__cli_data_dir}/active_shell"
      echo "$(date +%s)" >"${host__cli_data_dir}/active_shell"
      sleep 3
    done
  } &

  # For additional safety, ensure the container is up and running before trying to start the daemon.
  while ! docker exec "${host__container_name}" echo "" >/dev/null 2>&1; do
    sleep .2
  done
  local daemon_script_path=".solos/repo/src/daemon/daemon.sh"
  docker exec "${host__container_name}" \
    /bin/bash -c 'nohup "/root/'"${daemon_script_path}"'" >/dev/null 2>&1 &' >/dev/null
  host.log_info "Started the daemon script: ~/${daemon_script_path}"

  # Catch implementation errors due to non-existent rcfiles.
  # Otherwise, start the shell.
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
  if [[ ${host__force_rebuild} = true ]]; then
    if ! host.build; then
      host.log_error "Failed to rebuild the SolOS container."
      lib.enter_to_exit
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
    # Don't use host__curr_checked_out_project here because the checked out project could have changed
    # as a result of running the command.
    local checked_out_project="$(lib.checked_out_project)"
    if [[ -n ${checked_out_project} ]]; then
      local code_workspace_file="${HOME}/.solos/projects/${checked_out_project}/.vscode/${checked_out_project}.code-workspace"
      if [[ -f ${code_workspace_file} ]]; then
        code "${code_workspace_file}"
      fi
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
