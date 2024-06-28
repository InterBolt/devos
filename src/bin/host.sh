#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

. "${HOME}/.solos/repo/src/shared/lib.universal.sh" || exit 1

host__repo_dir="${HOME}/.solos/repo"
host__base_dockerfile_path="${host__repo_dir}/src/Dockerfile"
host__project_fallback_dockerfile_path="${host__repo_dir}/src/Dockerfile.project"
host__data_dir="$(lib.data_dir_path)"
host__base_image_name="solos:latest"
host__solos_default_project_name="solos-default"
host__bin_path="/root/.solos/repo/src/bin/container.sh"
host__project_container_name="solos-checked-out-project"
host__project_image_name="solos-checked-out-project:latest"
host__store_dir="${host__data_dir}/store"
host__hide_log_output=false
host__cli_data_dir="${host__data_dir}/cli"
host__daemon_data_dir="${host__data_dir}/cli"
host__log_file="${host__cli_data_dir}/master.log"
host__built_project_file="${host__data_dir}/cli/built_project"
host__built_project_from_file="${host__data_dir}/cli/built_project_from"
host__daemon_last_active_at_file="${host__data_dir}/daemon/last_active_at"

if [[ ! -f ${host__log_file} ]]; then
  mkdir -p "${host__cli_data_dir}"
  touch "${host__log_file}"
fi
host.log_info() {
  local msg="(CLI:HOST) ${1}"
  echo "INFO ${msg}" >>"${host__log_file}"
  echo -e "\033[1;32mINFO \033[0m${msg}" >&2
}
host.log_warn() {
  local msg="(CLI:HOST) ${1}"
  echo "WARN ${msg}" >>"${host__log_file}"
  echo -e "\033[1;33mWARN \033[0m${msg}" >&2
}
host.log_error() {
  local msg="(CLI:HOST) ${1}"
  echo "ERROR ${msg}" >>"${host__log_file}"
  echo -e "\033[1;31mERROR \033[0m${msg}" >&2
}
host.is_reserved_name() {
  if [[ ${next_project} = "${host__solos_default_project_name}" ]]; then
    return 0
  fi
  local reserved_names="help noop shell shell-minimal checkout vscode daemon daemon:start daemon:stop"
  for reserved_name in ${reserved_names}; do
    if [[ ${next_project} = "${reserved_name}" ]]; then
      return 0
    fi
  done
  return 1
}
# We want rebuilds to happen under the following conditions:
# 1) The user has never built a project before.
# 2) The user is running a command or shell for a project that is different from the one that was last built.
# 3) The project was not checked out on the previous run but now is, which means the dockerfile path changed.
# 4) The container is not running.
host.rebuild_is_necessary() {
  local checked_out_project="$(lib.checked_out_project)"
  local next_project="${1:-"${checked_out_project}"}"
  local next_project_from_file="${HOME}/.solos/projects/${next_project}/Dockerfile"
  if [[ ! -f ${next_project_from_file} ]]; then
    next_project_from_file="${host__project_fallback_dockerfile_path}"
  fi
  local built_project="$(cat "${host__built_project_file}" 2>/dev/null || echo "")"
  local built_project_from_file="$(cat "${host__built_project_from_file}" 2>/dev/null || echo "")"
  if [[ -z ${built_project} ]]; then
    return 0
  elif [[ -z ${built_project_from_file} ]]; then
    return 0
  elif [[ ${next_project} != "${built_project}" ]]; then
    return 0
  elif [[ ${next_project_from_file} != "${built_project_from_file}" ]]; then
    return 0
  elif ! docker exec "${host__project_container_name}" echo "" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}
host.rebuild() {
  # `next_project` is the project that we want to build a container for.
  # `next_project` does not need to be checked out in order for us to build it.
  # Once the checkout happens, our `host.rebuild_is_necessary` function will ensure we run `host.rebuild`
  # again, but this time with the generated project-specific dockerfile.
  local next_project="${1:-""}"
  if [[ -z ${next_project} ]]; then
    host.log_error "Unexpected - cannot build a project container without specifying a project name."
    return 1
  fi

  # Destroy everything.
  local image_names="$(docker ps -a --format '{{.Image}}' | xargs)"
  for image_name in ${image_names}; do
    if [[ ${image_name} = "${host__base_image_name}" ]] || [[ ${image_name} = "${host__project_image_name}" ]]; then
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

  # Projects not yet checked out will not have a generated project-specific dockerfile.
  # So we must use the default project dockerfile.
  local next_project_dockerfile_path="${HOME}/.solos/projects/${next_project}/Dockerfile"
  local project_dockerfile_path=""
  if [[ -f ${next_project_dockerfile_path} ]]; then
    project_dockerfile_path="${next_project_dockerfile_path}"
  else
    project_dockerfile_path="${host__project_fallback_dockerfile_path}"
  fi

  # Don't allow the user to build a dockerfile that doesn't extend the solos:latest base image.
  local project_dockerfile_contents="$(cat "${project_dockerfile_path}")"
  local project_dockerfile_first_line="$(
    echo "${project_dockerfile_contents}" | grep -vE '^\s*#' | grep -vE '^\s*$' | head -n 1 | xargs
  )"
  if [[ ${project_dockerfile_first_line} != 'FROM '"${host__base_image_name}"'' ]]; then
    host.log_error "User error: SolOS expects the first statement in ${project_dockerfile_path} to be: \`FROM solos:latest\`."
    return 1
  fi

  # Build the base image, and the project image if a project is checked out.
  if ! docker build -t "${host__base_dockerfile_path}" -f "${host__base_image_name}" . >/dev/null; then
    host.log_error "Failed to build the dockerfile: ${host__base_dockerfile_path}."
    return 1
  fi
  host.log_info "Built the base docker image - ${host__base_image_name}"
  if ! docker build -t "${project_dockerfile_path}" -f "${host__project_image_name}" . >/dev/null; then
    host.log_error "Failed to build the dockerfile: ${project_dockerfile_path}."
    return 1
  fi
  host.log_info "Built the project docker image - ${host__project_image_name}"

  # Need these values to determine whether or not rebuilds should happen in the future.
  echo "${project_dockerfile_path}" >"${host__built_project_from_file}"
  echo "${next_project}" >"${host__built_project_file}"

  # Save the user's home directory for reference inside the container.
  if [[ ! -d ${host__store_dir} ]]; then
    mkdir -p "${host__store_dir}"
  fi
  local curr_home_dir="$(cat "${host__store_dir}/users_home_dir" 2>/dev/null || echo "")"
  if [[ ${HOME} != "${curr_home_dir}" ]]; then
    echo "${HOME}" >"${host__store_dir}/users_home_dir"
    host.log_info "Saved the user's home directory to the store directory."
  fi

  # Start the project container.
  if ! docker run \
    -d \
    --name "${host__project_container_name}" \
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
  host.log_info "Started the \`"${host__project_container_name}"\` container using image: ${docker_project_image}"
  while ! docker exec "${host__project_container_name}" echo "" >/dev/null 2>&1; do
    sleep .2
  done
  host.log_info "The SolOS container is ready."
}
host.checkout() {
  local next_project="${1}"
  if host.is_reserved_name "${next_project}"; then
    host.log_error "Not allowed - the project name \`${next_project}\` is reserved in SolOS."
  fi
  if host.rebuild_is_necessary "${next_project}"; then
    if ! host.rebuild "${next_project}"; then
      host.log_error "Failed to rebuild the SolOS container."
      return 1
    fi
  fi
  local checked_out_project="$(lib.checked_out_project)"
  if [[ ${checked_out_project} = "${next_project}" ]]; then
    return 0
  fi
  docker exec -it "${host__project_container_name}" /bin/bash -c '"'"${host__bin_path}"'" "'"${next_project}"'"'
  local container_exit_code="$?"
  if [[ ${container_exit_code} -ne 0 ]]; then
    host.log_error "Unexpected - the \`vscode\` command failed and exited with a non-zero exit code: ${container_exit_code}"
    return "${container_exit_code}"
  fi
  checked_out_project="$(lib.checked_out_project)"
  if [[ ${checked_out_project} != "${next_project}" ]]; then
    host.log_error "Unexpected - the checked out project is not the one we expected: ${checked_out_project}"
    return 1
  else
    if host.rebuild_is_necessary "${next_project}"; then
      host.log_info "Rebuilding the Docker container based on a new Dockerfile generated during the checkout process: ${HOME}/.solos/projects/${next_project}/Dockerfile"
      if ! host.rebuild "${next_project}"; then
        host.log_error "Failed to rebuild the SolOS container."
        return 1
      fi
    fi
    return 0
  fi
  host.log_error "Unexpected - something went wrong and the checked out project could not be determined."
  return 1
}
host.shell_entry() {
  local next_project="${1:-""}"
  local bashrc_file="${2:-""}"
  local mounted_volume_dir="${HOME}/.solos"
  local working_dir="${3:-"${mounted_volume_dir}"}"
  local container_ctx="${working_dir/#$HOME//root}"
  if [[ ${container_ctx} != "/root/.solos"* ]]; then
    container_ctx="/root/.solos"
  fi
  if [[ -z ${next_project} ]]; then
    host.log_error "Shells must be associated with a checked out project. No project name was supplied."
    lib.enter_to_exit
  fi
  if ! host.checkout "${next_project}"; then
    host.log_error "Failed to check out project: ${next_project}"
    lib.enter_to_exit
  fi
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      host.log_error "The supplied bashrc file at ${bashrc_file} does not exist."
      lib.enter_to_exit
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    if ! docker exec -it -w "${container_ctx}" "${host__project_container_name}" /bin/bash --rcfile "${relative_bashrc_file}" -i; then
      host.log_error "Failed to start the shell with the supplied bashrc file."
      lib.enter_to_exit
    fi
  elif ! docker exec -it -w "${container_ctx}" "${host__project_container_name}" /bin/bash -i; then
    host.log_error "Failed to start the shell."
    lib.enter_to_exit
  fi
}
host.bin_entry() {
  local checked_out_project="$(lib.checked_out_project)"
  local next_project="${1}"
  if host.is_reserved "${next_project}"; then
    host.log_error "Not allowed - the project name \`${next_project}\` is reserved in SolOS."
  fi
  if [[ -z ${next_project} ]]; then
    if [[ -n ${checked_out_project} ]]; then
      next_project="${checked_out_project}"
    else
      next_project="${host__solos_default_project_name}"
    fi
  fi
  local cmd="${2}"
  if [[ -z ${cmd} ]]; then
    host.log_error "No command was supplied."
    return 1
  fi
  if host.rebuild_is_necessary "${next_project}"; then
    if ! host.rebuild "${next_project}"; then
      host.log_error "Failed to rebuild the SolOS container."
      return 1
    fi
  fi
  if [[ ${cmd} = "help" ]] || [[ ${cmd} = "noop" ]]; then
    docker exec -it "${host__project_container_name}" /bin/bash -c '"'"${host__bin_path}"'" '"${cmd}"''
    local container_exit_code="$?"
    if [[ ${container_exit_code} -ne 0 ]]; then
      host.log_error "Unexpected - the \`${cmd}\` command failed and exited with a non-zero exit code: ${container_exit_code}"
      return "${container_exit_code}"
    fi
    return 0
  fi
  if [[ ${cmd} = "checkout" ]]; then
    if host.checkout "${next_project}"; then
      host.log_info "Checked out project: ${next_project}"
      return 0
    else
      host.log_error "Failed to check out project: ${next_project}"
      return 1
    fi
  fi
  if [[ ${cmd} = "vscode" ]]; then
    if host.checkout "${next_project}"; then
      local code_workspace_file="${HOME}/.solos/projects/${next_project}/.vscode/${next_project}.code-workspace"
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
      host.log_error "Failed to check out project: ${next_project}"
      return 1
    fi
  fi
}
host.daemon_entry() {
  local next_project="${1}"
  local command="${2}"
  if [[ ${command} = "stop" ]]; then
    echo "KILL" >"${host__daemon_data_dir}/request"
  fi
  # last_active_at is string in format:
  # <project> <seconds>
  local last_active_at="$(cat "${host__daemon_last_active_at_file}" 2>/dev/null || echo "")"
  if [[ -n ${last_active_at} ]]; then
    local last_active_project="$(echo "${last_active_at}" | tr -s ' ' | cut -d' ' -f1)"
    local last_active_seconds="$(echo "${last_active_at}" | tr -s ' ' | cut -d' ' -f2)"
    if [[ ${last_active_project} != "${next_project}" ]]; then
      host.log_warn "The project you checked out or supplied is not associated with the last active daemon."
      return 1
    fi
    local last_active_at_epoch="$(date -d "${last_active_at}" +%s)"
    local curr_epoch="$(date +%s)"
    local diff="$((curr_epoch - last_active_at_epoch))"
    if [[ ${diff} -lt 60 ]]; then
      host.log_info "Daemon might be running. Will check again in 10 seconds to confirm."
    fi
  fi
  host.log_info "Waiting 10 seconds for the daemon to stop."
  sleep 10
  # TODO

}
host() {
  local checked_out_project="$(lib.checked_out_project)"
  if [[ ${1} = "shell" ]]; then
    host.shell_entry "${2}" "${HOME}/.solos/rcfiles/.bashrc" "${PWD}"
    exit $?
  elif [[ ${1} = "shell-minimal" ]]; then
    host.shell_entry "${2}" "" "${PWD}"
    exit $?
  elif [[ ${1} = "daemon:start" ]]; then
    host.daemon_entry "${2:-"${checked_out_project}"}" start
    exit $?
  elif [[ ${1} = "daemon:stop" ]]; then
    host.daemon_entry "${2:-"${checked_out_project}"}" stop
    exit $?
  elif [[ ${1} = "vscode" ]]; then
    host.bin_entry "${2}" vscode
    exit $?
  elif [[ ${1} = "checkout" ]]; then
    host.bin_entry "${2}" checkout
    exit $?
  elif [[ ${1} = "noop" ]]; then
    host.bin_entry "" noop
    exit $?
  elif [[ -z ${1} ]] || [[ ${1} = "help" ]] || [[ ${1} = "--help" ]] || [[ ${1} = "-h" ]]; then
    host.bin_entry "" help
    exit $?
  else
    host.log_error "Unknown command supplied: ${1}"
    exit 1
  fi
}

host "$@"
