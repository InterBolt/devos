#!/usr/bin/env bash

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
__docker__var__volume_config_hostfile="${__docker__var__volume_root}/store/users_home_dir"
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

# Make sure we can use the gum cli utilities
. "${HOME}/.solos/src/pkg/gum.sh"

__docker__fn__hash() {
  git -C "${__docker__var__volume_root}/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
__docker__fn__destroy() {
  for image_name in $(docker ps -a --format '{{.Image}}'); do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
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
  cd "${HOME}/.solos/src" || exit 1
  ./profile/relay-cmd-server.sh || exit 1
  cd "${entry_dir}" || exit 1
  docker exec "${args[@]}" /bin/bash --rcfile "${relative_bashrc_path}" -i
}
__docker__fn__exec_command() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  local bash_args=()
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__docker__fn__hash)")
    bash_args=(-c ''"${*}"'')
  else
    args=(-it -w "${container_ctx}" "$(__docker__fn__hash)")
    bash_args=(-i -c ''"${*}"'')
  fi
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
__docker__fn__build_and_run() {
  if [[ -f ${__docker__var__volume_root} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__docker__var__volume_config_hostfile}")"
  echo "${HOME}" >"${__docker__var__volume_config_hostfile}"
  if ! docker build -t "solos:$(__docker__fn__hash)" -f "${__docker__var__repo_launch_dir}/Dockerfile.shell" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  local shared_docker_run_args=(
    --name "$(__docker__fn__hash)"
    -d
    --network
    host
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
  if ! __docker__fn__destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    exit 1
  fi
  __docker__fn__build_and_run
  __docker__fn__exec_shell
}
__docker__fn__run() {
  if __docker__fn__test; then
    __docker__fn__exec_command "$@"
    return 0
  fi
  if ! __docker__fn__destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    exit 1
  fi
  __docker__fn__build_and_run
  __docker__fn__exec_command "$@"
}
