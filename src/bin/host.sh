#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

. "${HOME}/.solos/repo/src/shared/lib.universal.sh" || exit 1

# Base directories.
host__solos_repo_dir="${HOME}/.solos/repo"
host__solos_data_dir="${HOME}/.solos/data"
# Docker stuff.
host__base_dockerfile="${host__solos_repo_dir}/src/Dockerfile"
host__project_fallback_dockerfile="${host__solos_repo_dir}/src/Dockerfile.project"
host__base_docker_image="solos:latest"
host__project_docker_image="solos-checked-out-project:latest"
host__project_docker_container="solos-checked-out-project"
host__fallback_project_docker_container="solos-default-project"
# Paths specific to the docker FS.
host__containerized_bin_path="/root/.solos/repo/src/bin/container.sh"
host__containerized_daemon_path="/root/.solos/repo/src/daemon/daemon.sh"
# Files used to communicated information between the host and the container.
host__data_store_users_home_dir_file="${host__solos_data_dir}/store/users_home_dir"
host__data_cli_dir_master_log_file="${host__solos_data_dir}/cli/master.log"
host__data_cli_dir_built_project_file="${host__solos_data_dir}/cli/built_project"
host__data_cli_dir_built_project_from_dockerfile_file="${host__solos_data_dir}/cli/built_project_from"
host__data_daemon_last_active_at_file="${host__solos_data_dir}/daemon/last_active_at"
host__data_daemon_master_log_file="${host__solos_data_dir}/daemon/master.log"

##
## LOGGING
##

mkdir -p "$(dirname "${host__data_cli_dir_master_log_file}")"
touch "${host__data_cli_dir_master_log_file}"
host.log_info() {
  local msg="(CLI:HOST) ${1}"
  echo "INFO ${msg}" >>"${host__data_cli_dir_master_log_file}"
  echo -e "\033[1;32mINFO \033[0m${msg}" >&2
}
host.log_warn() {
  local msg="(CLI:HOST) ${1}"
  echo "WARN ${msg}" >>"${host__data_cli_dir_master_log_file}"
  echo -e "\033[1;33mWARN \033[0m${msg}" >&2
}
host.log_error() {
  local msg="(CLI:HOST) ${1}"
  echo "ERROR ${msg}" >>"${host__data_cli_dir_master_log_file}"
  echo -e "\033[1;31mERROR \033[0m${msg}" >&2
}

##
## UTILITIES
##

# Enforce some assumptions around what project names can/cannot used.
host.is_invalid_project_name() {
  local target_project="${1:-""}"
  if [[ -z ${target_project} ]]; then
    host.log_error "Project name cannot be empty."
    return 0
  fi
  if [[ ${target_project} = "${host__fallback_project_docker_container}" ]]; then
    host.log_error "The project name \`${target_project}\` is reserved in SolOS."
    return 0
  fi
  local reserved_names="shell shell-minimal checkout vscode daemon daemon:start daemon:stop"
  for reserved_name in ${reserved_names}; do
    if [[ ${target_project} = "${reserved_name}" ]]; then
      host.log_error "The project name \`${target_project}\` is reserved in SolOS."
      return 0
    fi
  done
  if [[ ! ${target_project} =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
    host.log_error "Project name must start with a letter and contain only letters, numbers, and underscores."
    return 0
  fi
  return 1
}

# We want rebuilds to happen under the following conditions:
# 1) The user has never built a project before.
# 2) The project is different from the one that was last built.
# 3) The project was not checked out before but now it is (post-checkout projects use a different dockerfile).
# 4) The container is not running.
host.is_rebuild_necessary() {
  local checked_out_project="$(lib.checked_out_project)"
  local target_project="${1:-"${checked_out_project}"}"
  local target_project_dockerfile="${HOME}/.solos/projects/${target_project}/Dockerfile"
  if [[ ! -f ${target_project_dockerfile} ]]; then
    target_project_dockerfile="${host__project_fallback_dockerfile}"
  fi
  local built_project="$(cat "${host__data_cli_dir_built_project_file}" 2>/dev/null || echo "")"
  local built_project_from_dockerfile="$(cat "${host__data_cli_dir_built_project_from_dockerfile_file}" 2>/dev/null || echo "")"
  if [[ -z ${built_project} ]]; then
    return 0
  elif [[ -z ${built_project_from_dockerfile} ]]; then
    return 0
  elif [[ ${target_project} != "${built_project}" ]]; then
    return 0
  elif [[ ${target_project_dockerfile} != "${built_project_from_dockerfile}" ]]; then
    return 0
  elif ! docker exec "${host__project_docker_container}" echo "" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Outline:
# - destroy existing containers and images.
# - mark the daemon as inactive.
# - determine which dockerfile to use for the project (the custom one or the default one).
# - ensure the dockerfile for the project extends the solos:latest base image.
# - build the base image.
# - build the project image.
# - save the project name and dockerfile path used to build the container to a file.
# - save the user's home directory to a file.
# - start the project container.
# - wait for the container to be ready.
host.rebuild() {
  # `target_project` is the project that we want to build a container for.
  # `target_project` does not need to be checked out in order for us to build it.
  # Once the checkout happens, other logic will determine if a rebuild is necessary.
  local target_project="${1:-""}"
  if [[ -z ${target_project} ]]; then
    host.log_error "Unexpected - cannot build a project container without specifying a project name."
    return 1
  fi

  # Destroy everything.
  local image_names="$(docker ps -a --format '{{.Image}}' | xargs)"
  for image_name in ${image_names}; do
    if [[ ${image_name} = "${host__base_docker_image}" ]] || [[ ${image_name} = "${host__project_docker_image}" ]]; then
      host.log_info "Stopping container(s) running image: ${image_name}"
      if ! docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null; then
        host.log_error "Failed to stop the container with image name ${image_name}."
        return 1
      fi
      host.log_info "Removing container(s) running image: ${image_name}"
      if ! docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null; then
        host.log_error "Failed to remove the container with image name ${image_name}."
        return 1
      fi
      host.log_info "Removing image: ${image_name}"
      if ! docker rmi "${image_name}" >/dev/null; then
        host.log_error "Failed to remove the image with image name ${image_name}."
        return 1
      fi
    fi
  done

  # Mark the daemon as inactive.
  rm -f "${host__data_daemon_last_active_at_file}"
  host.log_info "Daemon was marked as inactive."

  # Only projects that were checked out will have a custom Dockerfile.
  local target_project_dockerfile="${HOME}/.solos/projects/${target_project}/Dockerfile"
  local project_dockerfile=""
  if [[ -f ${target_project_dockerfile} ]]; then
    project_dockerfile="${target_project_dockerfile}"
  else
    project_dockerfile="${host__project_fallback_dockerfile}"
  fi

  # Don't allow the user to build a dockerfile that doesn't extend the solos:latest base image.
  local project_dockerfile_first_line="$(
    cat "${project_dockerfile}" | grep -vE '^\s*#' | grep -vE '^\s*$' | head -n 1 | xargs
  )"
  if [[ ${project_dockerfile_first_line} != 'FROM '"${host__base_docker_image}"'' ]]; then
    host.log_error "User error: SolOS expects the first statement in ${project_dockerfile} to be: \`FROM solos:latest\`."
    return 1
  fi

  # Build the base image, and the project image if a project is checked out.
  if ! docker build -t "${host__base_dockerfile}" -f "${host__base_docker_image}" . >/dev/null; then
    host.log_error "Failed to build the dockerfile: ${host__base_dockerfile}."
    return 1
  fi
  host.log_info "Built the base docker image - ${host__base_docker_image}"
  if ! docker build -t "${project_dockerfile}" -f "${host__project_docker_image}" . >/dev/null; then
    host.log_error "Failed to build the dockerfile: ${project_dockerfile}."
    return 1
  fi
  host.log_info "Built the project docker image - ${host__project_docker_image}"

  # Need these values to determine whether or not rebuilds should happen in the future.
  echo "${project_dockerfile}" >"${host__data_cli_dir_built_project_from_dockerfile_file}"
  echo "${target_project}" >"${host__data_cli_dir_built_project_file}"

  # Save the user's home directory for reference inside the container.
  local curr_home_dir="$(cat "${host__data_store_users_home_dir_file}" 2>/dev/null || echo "")"
  if [[ ${HOME} != "${curr_home_dir}" ]]; then
    mkdir -p "$(dirname "${host__data_store_users_home_dir_file}")"
    echo "${HOME}" >"${host__data_store_users_home_dir_file}"
    host.log_info "Saved the user's home directory to the store directory."
  fi

  # Start the project container.
  if ! docker run \
    -d \
    --name "${host__project_docker_container}" \
    --network host \
    --pid host \
    --privileged \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    -v "${HOME}/.solos:/root/.solos" \
    "${docker_project_image}" tail -f /dev/null >/dev/null; then
    host.log_error "Failed to run the docker container."
    return 1
  fi

  # Wait for the container to be ready by checking if we can execute an echo command inside it.
  host.log_info "Started the \`"${host__project_docker_container}"\` container using image: ${docker_project_image}"
  while ! docker exec "${host__project_docker_container}" echo "" >/dev/null 2>&1; do
    sleep .2
  done
  host.log_info "The SolOS container is ready."
}

# TODO: describe
host.checkout() {
  local target_project="${1}"
  if host.is_invalid_project_name "${target_project}"; then
    return 1
  fi
  local was_rebuilt=false
  if host.is_rebuild_necessary "${target_project}"; then
    if ! host.rebuild "${target_project}"; then
      host.log_error "Failed to rebuild the SolOS container for project: ${target_project}"
      return 1
    fi
    was_rebuilt=true
  fi
  if [[ ${was_rebuilt} = true ]]; then
    if ! host.start_daemon "${target_project}"; then
      host.log_error "Failed to start the daemon for project: ${target_project}"
      return 1
    fi
  elif ! host.was_daemon_active_at "${target_project}" "15"; then
    local curr_seconds="$(date +%s)"
    host.log_info "The daemon appears to be inactive. Will check again in 5 seconds."
    sleep 5
    # Now, check to see if the daemon updated it's activity file while we slept.
    if ! host.was_daemon_active_at "${target_project}" "6"; then
      host.log_info "Still no activity from the daemon. Will attempt to start it."
      if ! host.start_daemon "${target_project}"; then
        host.log_error "Failed to start the daemon for project: ${target_project}"
        if [[ ${was_rebuilt} = false ]]; then
          if ! host.rebuild "${target_project}"; then
            host.log_error "Failed to rebuild the SolOS container for project: ${target_project}"
            return 1
          fi
        fi
        return 1
      fi
    fi
  fi

  local checked_out_project="$(lib.checked_out_project)"
  if [[ ${checked_out_project} = "${target_project}" ]]; then
    return 0
  fi
  docker exec -it "${host__project_docker_container}" /bin/bash -c '"'"${host__containerized_bin_path}"'" "'"${target_project}"'"'
  local container_exit_code="$?"
  if [[ ${container_exit_code} -ne 0 ]]; then
    host.log_error "Unexpected - the \`vscode\` command failed and exited with a non-zero exit code: ${container_exit_code}"
    return "${container_exit_code}"
  fi
  checked_out_project="$(lib.checked_out_project)"
  if [[ ${checked_out_project} != "${target_project}" ]]; then
    host.log_error "Unexpected - the checked out project is not the one we expected: ${checked_out_project}"
    return 1
  else
    if host.is_rebuild_necessary "${target_project}"; then
      host.log_info "Rebuilding the Docker container based on a new Dockerfile generated during the checkout process: ${HOME}/.solos/projects/${target_project}/Dockerfile"
      if ! host.rebuild "${target_project}"; then
        host.log_error "Failed to rebuild the SolOS container for project: ${target_project}"
        return 1
      fi
    fi
    return 0
  fi
  host.log_error "Unexpected - something went wrong and the checked out project could not be determined."
  return 1
}

# TODO: describe
host.start_daemon() {
  local target_project="${1}"
  if ! docker exec "${host__project_docker_container}" echo "" >/dev/null 2>&1; then
    host.log_error "The container is not running. Cannot start the daemon."
    return 1
  fi
  if docker exec "${host__project_docker_container}" \
    /bin/bash -c 'nohup "'"${host__containerized_daemon_path}"'" >/dev/null 2>&1 &' >/dev/null; then
    echo "${target_project} $(date +%s)" >"${host__data_daemon_last_active_at_file}"
    host.log_info "Started the daemon for project: ${target_project}"
    return 0
  fi
  return 1
}

# TODO: describe
host.was_daemon_active_at() {
  local target_project="${1}"
  local seconds_considered_active="${2:-10}"
  local last_active_at="$(cat "${host__data_daemon_last_active_at_file}" 2>/dev/null || echo "")"
  if [[ -z ${last_active_at} ]]; then
    return 1
  fi
  local last_active_project="$(echo "${last_active_at}" | tr -s ' ' | cut -d' ' -f1)"
  local last_active_seconds="$(echo "${last_active_at}" | tr -s ' ' | cut -d' ' -f2)"
  if [[ ${last_active_project} != "${target_project}" ]]; then
    return 1
  fi
  local curr_seconds="$(date +%s)"
  if [[ $((curr_seconds - last_active_seconds)) -lt "${seconds_considered_active}" ]]; then
    return 0
  fi
  return 1
}

host.shell_entry() {
  local target_project="${1:-""}"
  if host.is_invalid_project_name "${target_project}"; then
    return 1
  fi
  local bashrc_file="${2:-""}"
  local mounted_volume_dir="${HOME}/.solos"
  local working_dir="${3:-"${mounted_volume_dir}"}"
  local container_ctx="${working_dir/#$HOME//root}"
  if [[ ${container_ctx} != "/root/.solos"* ]]; then
    container_ctx="/root/.solos"
  fi
  if [[ -z ${target_project} ]]; then
    host.log_error "Shells must be associated with a checked out project. No project name was supplied."
    lib.enter_to_exit
  fi
  if ! host.checkout "${target_project}"; then
    host.log_error "Failed to check out project: ${target_project}"
    lib.enter_to_exit
  fi
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      host.log_error "The supplied bashrc file at ${bashrc_file} does not exist."
      lib.enter_to_exit
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    if ! docker exec -it -w "${container_ctx}" "${host__project_docker_container}" /bin/bash --rcfile "${relative_bashrc_file}" -i; then
      host.log_error "Failed to start the shell with the supplied bashrc file."
      lib.enter_to_exit
    fi
  elif ! docker exec -it -w "${container_ctx}" "${host__project_docker_container}" /bin/bash -i; then
    host.log_error "Failed to start the shell."
    lib.enter_to_exit
  fi
}
host.bin_entry() {
  local target_project="${1}"
  local cmd="${2}"
  if host.is_invalid_project_name "${target_project}"; then
    return 1
  fi
  if [[ -z ${cmd} ]]; then
    host.log_error "No command was supplied."
    return 1
  fi
  if host.is_rebuild_necessary "${target_project}"; then
    if ! host.rebuild "${target_project}"; then
      host.log_error "Failed to rebuild the SolOS container for project: ${target_project}"
      return 1
    fi
  fi
  if [[ ${cmd} = "--help" ]] || [[ ${cmd} = "--noop" ]]; then
    docker exec -it "${host__project_docker_container}" /bin/bash -c '"'"${host__containerized_bin_path}"'" '"${cmd}"''
    local container_exit_code="$?"
    if [[ ${container_exit_code} -ne 0 ]]; then
      return "${container_exit_code}"
    fi
    return 0
  fi
  if [[ ${cmd} = "checkout" ]]; then
    if host.checkout "${target_project}"; then
      host.log_info "Checked out project: ${target_project}"
      return 0
    else
      host.log_error "Failed to check out project: ${target_project}"
      return 1
    fi
  fi
  if [[ ${cmd} = "vscode" ]]; then
    if host.checkout "${target_project}"; then
      local code_workspace_file="${HOME}/.solos/projects/${target_project}/.vscode/${target_project}.code-workspace"
      if [[ -f ${code_workspace_file} ]]; then
        if command -v code >/dev/null; then
          code "${code_workspace_file}"
        else
          host.log_info "Launch VSCode workspace with: ${code_workspace_file}"
        fi
        return 0
      else
        host.log_error "Failed to find a code-workspace file at: ${code_workspace_file}"
        return 1
      fi
    else
      host.log_error "Failed to check out project: ${target_project}"
      return 1
    fi
  fi
}
host.daemon_entry() {
  local target_project="${1}"
  local command="${2}"
  if [[ ${command} = "stop" ]]; then
    echo "KILL" >"${host__daemon_data_dir}/request"
    local tries=0
    local confirmations=0
    # Give daemon a grace period of 15 seconds to stop cleanly.
    while true; do
      local status="$(cat "${host__daemon_data_dir}/status" 2>/dev/null || echo "")"
      if [[ ${status} != "UP" ]]; then
        if [[ ${confirmations} -gt 0 ]]; then
          host.log_info "The daemon has been stopped."
          break
        fi
        confirmations="$((confirmations + 1))"
        break
      fi
      if [[ ${tries} -gt 15 ]]; then
        host.log_error "Having trouble stopping the daemon. Will proceed to rebuild the Docker container in which it runs."
        break
      fi
      tries="$((tries + 1))"
      sleep 1
    done
    if ! host.rebuild "${target_project}"; then
      host.log_error "Failed to rebuild the container for project: ${target_project}"
      return 1
    fi
    if ! host.start_daemon "${target_project}"; then
      host.log_info "Failed to start the daemon for project: ${target_project}"
      return 1
    fi
    host.log_info "Successfully launched the daemon for project: ${target_project}"
    host.log_info "View daemon logs at: \"${host__data_daemon_master_log_file}\"\`"
    return 0
  fi
  if [[ ${command} = "start" ]]; then
    local max_time=10
    if host.was_daemon_active_at "${target_project}" "${max_time}"; then
      host.log_warn "The daemon was active within the last ${max_time} seconds. Not starting a new daemon."
      return 1
    fi
    host.log_info "An active daemon was not found for the project: ${target_project}. Rebuilding..."
    if ! host.rebuild "${target_project}"; then
      host.log_error "Failed to rebuild the container for project: ${target_project}"
      return 1
    fi
    if ! host.start_daemon "${target_project}"; then
      host.log_info "Failed to start the daemon for project: ${target_project}"
      return 1
    fi
    host.log_info "Successfully started the daemon for the project: ${target_project}"
    host.log_info "View daemon logs at: \"${host__data_daemon_master_log_file}\"\`"
    return 0
  fi
  host.log_error "Unknown command supplied: ${command}"
}
host() {
  local checked_out_project="$(lib.checked_out_project)"
  if [[ ${1} = "shell" ]]; then
    host.shell_entry "${2:-"${checked_out_project}"}" "${HOME}/.solos/rcfiles/.bashrc" "${PWD}"
    exit $?
  elif [[ ${1} = "shell-minimal" ]]; then
    host.shell_entry "${2:-"${checked_out_project}"}" "" "${PWD}"
    exit $?
  elif [[ ${1} = "daemon:start" ]]; then
    host.daemon_entry "${2:-"${checked_out_project}"}" start
    exit $?
  elif [[ ${1} = "daemon:stop" ]]; then
    host.daemon_entry "${2:-"${checked_out_project}"}" stop
    exit $?
  elif [[ ${1} = "vscode" ]]; then
    host.bin_entry "${2:-"${checked_out_project}"}" vscode
    exit $?
  elif [[ ${1} = "checkout" ]]; then
    host.bin_entry "${2:-"${checked_out_project}"}" checkout
    exit $?
  elif [[ ${1} = "noop" ]]; then
    host.bin_entry "${2:-"${checked_out_project}"}" --noop
    exit $?
  elif [[ -z ${1} ]] || [[ ${1} = "help" ]] || [[ ${1} = "--help" ]] || [[ ${1} = "-h" ]]; then
    host.bin_entry "${2:-"${checked_out_project}"}" --help
    exit $?
  else
    host.log_error "Unknown command supplied: ${1}"
    exit 1
  fi
}

host "$@"
