#!/usr/bin/env bash

__base__var__LIB_ENTRY_DIR="${PWD}"

cd "${HOME}" || exit 1

__base__var__RAG_DIR="${HOME}/.solos/rag"
__base__var__RAG_CAPTURED="${__base__var__RAG_DIR}/captured"
__base__var__LIB_VOLUME_ROOT="${HOME}/.solos"
__base__var__LIB_REPO_LAUNCH_DIR="${__base__var__LIB_VOLUME_ROOT}/src/bin/launch"
__base__var__LIB_SYMLINKED_PATH="$(readlink -f "$0" || echo "${HOME}/.solos/src/bin/solos.sh")"
if [[ -z ${__base__var__LIB_SYMLINKED_PATH} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
__base__var__LIB_BIN_DIR="$(dirname "${__base__var__LIB_SYMLINKED_PATH}")"
__base__var__LIB_REPO_DIR="$(dirname "${__base__var__LIB_BIN_DIR}")"
if ! cd "${__base__var__LIB_REPO_DIR}"; then
  echo "Unexpected error: could not cd into ${__base__var__LIB_REPO_DIR}" >&2
  exit 1
fi
__base__var__LIB_VOLUME_CONFIG_HOSTFILE="${__base__var__LIB_VOLUME_ROOT}/config/host"
__base__var__LIB_VOLUME_MOUNTED="/root/.solos"
__base__var__LIB_INSTALLER_NO_TTY_FLAG=false
__base__var__LIB_next_args=()
for entry_arg in "$@"; do
  if [[ $entry_arg = "--installer-no-tty" ]]; then
    __base__var__LIB_INSTALLER_NO_TTY_FLAG=true
  else
    __base__var__LIB_next_args+=("$entry_arg")
  fi
done
set -- "${__base__var__LIB_next_args[@]}" || exit 1

# Make the gum pkg available.
__base__var__ENTRY_DIR="${PWD}"
cd "${HOME}/.solos/src/bin" || exit 1
source pkg/__source__.sh
cd "${__base__var__ENTRY_DIR}" || exit 1

__base__fn__hash() {
  git -C "${__base__var__LIB_VOLUME_ROOT}/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
__base__fn__cleanup_old_containers() {
  local hash="$(__base__fn__hash)"
  for image_name in $(docker ps -a --format "{{.Image}}" --no-trunc); do
    if [[ ${image_name} = "solos-cli:"* ]]; then
      local image_hash="${image_name#solos-cli:}"
      if [[ ${image_hash} != "${hash}" ]]; then
        local container_id=$(docker ps -a --format "{{.ID}} {{.Image}}" --no-trunc | grep "${image_name}" | awk '{print $1}')
        if [[ -n ${container_id} ]]; then
          if ! docker rm -f "${container_id}" >/dev/null 2>&1; then
            echo "Failed to remove container: ${container_id}" >&2
            return 1
          fi
        fi
      fi
    fi
  done
}
__base__fn__test() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__base__var__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__base__fn__hash)" echo "")
  else
    args=(-it -w "${container_ctx}" "$(__base__fn__hash)" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
__base__fn__exec_shell() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__base__var__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__base__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__base__fn__hash)")
  fi
  local entry_dir="${PWD}"
  local bashrc_path="${HOME}/.solos/.bashrc"
  local relative_bashrc_path="${bashrc_path/#$HOME/~}"
  cd "${HOME}/.solos/src/bin" || exit 1
  ./profile/host-server.sh || exit 1
  cd "${entry_dir}" || exit 1
  docker exec "${args[@]}" /bin/bash --rcfile "${relative_bashrc_path}" -i
}
__base__fn__exec_command() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__base__var__LIB_INSTALcLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__base__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__base__fn__hash)")
  fi
  docker exec "${args[@]}" /bin/bash --rcfile ${HOME}/.solos/.bashrc -i -c ''"$@"'' |
    tee -a >(grep "^\[RAG\]" >>"${__base__var__RAG_CAPTURED}")
}
__base__fn__build_and_run() {
  # Initalize the home/.solos dir if it's not already there.
  if [[ -f ${__base__var__LIB_VOLUME_ROOT} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__base__var__LIB_VOLUME_CONFIG_HOSTFILE}")"
  echo "${HOME}" >"${__base__var__LIB_VOLUME_CONFIG_HOSTFILE}"
  # Build the base and cli images.
  if ! docker build -t "solos:base" -f "${__base__var__LIB_REPO_LAUNCH_DIR}/Dockerfile.base" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  if ! docker build -t "solos-cli:$(__base__fn__hash)" -f "${__base__var__LIB_REPO_LAUNCH_DIR}/Dockerfile.cli" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  # TODO: it could be nice to have the gitconfig mounted, but I'm trying to see if I can use
  # TODO[c] the "gh" cli to authenticate.
  # local gitconfig_path="$(
  #   git config --list --show-origin --global |
  #     grep "file:" |
  #     grep "gitconfig" |
  #     cut -d' ' -f1 |
  #     cut -d':' -f2 |
  #     head -n 1 |
  #     awk -F ' ' '{print $1}'
  # )"
  # local git_volume_args=()
  # if [[ -f ${gitconfig_path} ]]; then
  #   echo "Found gitconfig file: ${gitconfig_path}"
  #   git_volume_args=(
  #     -v
  #     "${gitconfig_path}:/etc/gitconfig"
  #   )
  # else
  #   echo "WARNING: Failed to locate a \`.gitconfig\`. Skipping automatic git integration." >&2
  # fi
  mkdir -p "${HOME}/.solos/secrets"
  local gh_token_path="${HOME}/.solos/secrets/gh_token"
  local gh_token=""
  if [[ -f ${gh_token_path} ]]; then
    gh_token=$(cat "${gh_token_path}")
  else
    pkg.gum.github_token >"${gh_token_path}" || exit 1
    gh_token=$(cat "${gh_token_path}")
  fi
  if [[ -z ${gh_token} ]]; then
    echo "A Github personal access token was not provided. Exiting..." >&2
    exit 1
  fi
  local shared_docker_run_args=(
    --name "$(__base__fn__hash)"
    -d
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${__base__var__LIB_VOLUME_ROOT}:${__base__var__LIB_VOLUME_MOUNTED}"
    "solos-cli:$(__base__fn__hash)"
  )
  if [[ ${__base__var__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! __base__fn__test; do
    sleep .2
  done
}
__base__fn__shell() {
  if __base__fn__test; then
    __base__fn__exec_shell
    return 0
  fi
  __base__fn__build_and_run
  if ! __base__fn__cleanup_old_containers; then
    echo "Failed to cleanup old containers. Continuing anyways..." >&2
  fi
  __base__fn__exec_shell
}
__base__fn__run() {
  if __base__fn__test; then
    __base__fn__exec_command "$@"
    return 0
  fi
  __base__fn__build_and_run
  if ! __base__fn__cleanup_old_containers; then
    echo "Failed to cleanup old containers. Continuing anyways..." >&2
  fi
  __base__fn__exec_command "$@"
}
