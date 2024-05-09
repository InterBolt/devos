#!/usr/bin/env bash

__docker__var__entry_dir="${PWD}"

cd "${HOME}" || exit 1

__docker__var__rag_dir="${HOME}/.solos/rag"
__docker__var__rag_captured="${__docker__var__rag_dir}/captured"
__docker__var__volume_root="${HOME}/.solos"
__docker__var__repo_launch_dir="${__docker__var__volume_root}/src/bin/launch"
__docker__var__symlinked_path="$(readlink -f "$0" || echo "${HOME}/.solos/src/bin/solos.sh")"
if [[ -z ${__docker__var__symlinked_path} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
__docker__var__bin_dir="$(dirname "${__docker__var__symlinked_path}")"
__docker__var__repo_dir="$(dirname "${__docker__var__bin_dir}")"
if ! cd "${__docker__var__repo_dir}"; then
  echo "Unexpected error: could not cd into ${__docker__var__repo_dir}" >&2
  exit 1
fi
__docker__var__volume_config_hostfile="${__docker__var__volume_root}/config/host"
__docker__var__volume_mounted="/root/.solos"
__docker__var__installer_no_tty_flag=false
__docker__var__next_args=()
for entry_arg in "$@"; do
  if [[ $entry_arg = "--installer-no-tty" ]]; then
    __docker__var__installer_no_tty_flag=true
  else
    __docker__var__next_args+=("$entry_arg")
  fi
done
set -- "${__docker__var__next_args[@]}" || exit 1

__docker__var__entry_dir="${PWD}"
cd "${HOME}/.solos/src/bin" || exit 1
source pkg/__source__.sh
cd "${__docker__var__entry_dir}" || exit 1

__docker__fn__hash() {
  git -C "${__docker__var__volume_root}/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
__docker__fn__cleanup_old_containers() {
  local hash="$(__docker__fn__hash)"
  for image_name in $(docker ps -a --format "{{.Image}}" --no-trunc); do
    if [[ ${image_name} = "solos:"* ]]; then
      local image_hash="${image_name#solos:}"
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
__docker__fn__test() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__docker__fn__hash)" echo "")
  else
    args=(-it -w "${container_ctx}" "$(__docker__fn__hash)" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
__docker__fn__exec_shell() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__docker__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__docker__fn__hash)")
  fi
  local entry_dir="${PWD}"
  local bashrc_path="${HOME}/.solos/.bashrc"
  local relative_bashrc_path="${bashrc_path/#$HOME/~}"
  cd "${HOME}/.solos/src/bin" || exit 1
  ./profile/host-server.sh || exit 1
  cd "${entry_dir}" || exit 1
  docker exec "${args[@]}" /bin/bash --rcfile "${relative_bashrc_path}" -i
}
__docker__fn__exec_command() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__docker__var__INSTALcLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__docker__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__docker__fn__hash)")
  fi
  docker exec "${args[@]}" /bin/bash --rcfile ${HOME}/.solos/.bashrc -i -c ''"$@"'' |
    tee -a >(grep "^\[RAG\]" >>"${__docker__var__rag_captured}")
}
__docker__fn__build_and_run() {
  if [[ -f ${__docker__var__volume_root} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__docker__var__volume_config_hostfile}")"
  echo "${HOME}" >"${__docker__var__volume_config_hostfile}"
  if ! docker build -t "solos:base" -f "${__docker__var__repo_launch_dir}/Dockerfile.base" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  if ! docker build -t "solos:$(__docker__fn__hash)" -f "${__docker__var__repo_launch_dir}/Dockerfile.shell" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
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
    --name "$(__docker__fn__hash)"
    -d
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${__docker__var__volume_root}:${__docker__var__volume_mounted}"
    "solos:$(__docker__fn__hash)"
  )
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! __docker__fn__test; do
    sleep .2
  done
}
__docker__fn__shell() {
  if __docker__fn__test; then
    __docker__fn__exec_shell
    return 0
  fi
  __docker__fn__build_and_run
  if ! __docker__fn__cleanup_old_containers; then
    echo "Failed to cleanup old containers. Continuing anyways..." >&2
  fi
  __docker__fn__exec_shell
}
__docker__fn__run() {
  if __docker__fn__test; then
    __docker__fn__exec_command "$@"
    return 0
  fi
  __docker__fn__build_and_run
  if ! __docker__fn__cleanup_old_containers; then
    echo "Failed to cleanup old containers. Continuing anyways..." >&2
  fi
  __docker__fn__exec_command "$@"
}
