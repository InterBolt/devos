#!/usr/bin/env bash

if ! command -v git >/dev/null 2>&1; then
  echo "Please install git and docker before running this script." >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "Please install docker before running this script." >&2
  exit 1
fi

__bridge__rag_dir="${HOME}/.solos/rag"
__bridge__rag_captured="${__bridge__rag_dir}/captured"
__bridge__repo_dir="${HOME}/.solos/src"
__bridge__cli_path="$(readlink -f "$0" || echo "${HOME}/.solos/src/container/cli.sh")"
if [[ -z ${__bridge__cli_path} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
__bridge__volume_config_hostfile="${HOME}/.solos/store/users_home_dir"
__bridge__volume_mounted="/root/.solos"
__bridge__installer_no_tty_flag=false
__bridge__minimal_flag=false
__bridge__session_flag=false
__bridge__next_args=()

for entry_arg in "$@"; do
  if [[ ${entry_arg} = "--installer-no-tty" ]]; then
    __bridge__installer_no_tty_flag=true
  elif [[ ${entry_arg} = "--minimal" ]]; then
    __bridge__minimal_flag=true
  elif [[ ${entry_arg} = "--session" ]]; then
    __bridge__session_flag=true
  else
    __bridge__next_args+=("${entry_arg}")
  fi
done
set -- "${__bridge__next_args[@]}" || exit 1

. "${HOME}/.solos/src/tools/pkgs/gum.sh"

__bridge__fn__hash() {
  git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
__bridge__fn__destroy() {
  for image_name in $(docker ps -a --format '{{.Image}}'); do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
    fi
  done
}
__bridge__fn__symlinks() {
  __bridge__fn__exec_command rm -rf /usr/local/bin/*_solos
  for solos_bin_file in "${HOME}/.solos/src/tools/cmds"/*; do
    local container_usr_bin_local_file="${solos_bin_file/#$HOME//root}"
    if [[ -f ${solos_bin_file} ]]; then
      chmod +x "${solos_bin_file}"
      __bridge__fn__exec_command ln -sf \
        "${container_usr_bin_local_file}" \
        "/usr/local/bin/$(basename "${container_usr_bin_local_file}" | cut -d'.' -f1)_solos"
    fi
  done
}
__bridge__fn__test() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__bridge__fn__hash)" echo "")
  else
    args=(-it -w "${container_ctx}" "$(__bridge__fn__hash)" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
__bridge__fn__exec_shell() {
  local bashrc_file="${1:-""}"
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__bridge__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__bridge__fn__hash)")
  fi
  local bash_args=()
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "The supplied bashrc file at ${bashrc_file} does not exist." >&2
      sleep 10
      exit 1
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    bash_args=(--rcfile "${relative_bashrc_file}")
  fi

  local entry_dir="${PWD}"
  cd "${HOME}/.solos/src" || exit 1
  ./host/background.sh || exit 1
  cd "${entry_dir}" || exit 1
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}" -i
}
__bridge__fn__exec_command() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  local bash_args=()
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__bridge__fn__hash)")
    bash_args=(-c ''"${*}"'')
  else
    args=(-it -w "${container_ctx}" "$(__bridge__fn__hash)")
    bash_args=(-i -c ''"${*}"'')
  fi
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
__bridge__fn__build_and_run() {
  if [[ -f ${HOME}/.solos ]]; then
    echo "Unhandled: a file called .solos was detected in your home directory." >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__bridge__volume_config_hostfile}")"
  echo "${HOME}" >"${__bridge__volume_config_hostfile}"
  if ! docker build -t "solos:$(__bridge__fn__hash)" -f "${__bridge__repo_dir}/Dockerfile" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    read -r -p "Press enter to exit..."
    exit 1
  fi
  local shared_docker_run_args=(
    --name
    "$(__bridge__fn__hash)"
    -d
    --network
    host
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${HOME}/.solos:${__bridge__volume_mounted}"
    "solos:$(__bridge__fn__hash)"
  )
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! __bridge__fn__test; do
    sleep .2
  done
}
__bridge__fn__session() {
  if __bridge__fn__test; then
    __bridge__fn__symlinks
    __bridge__fn__exec_shell "$@"
    return 0
  fi
  if ! __bridge__fn__destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    exit 1
  fi
  __bridge__fn__build_and_run
  __bridge__fn__symlinks
  __bridge__fn__exec_shell "$@"
}
__bridge__fn__cmd() {
  if __bridge__fn__test; then
    __bridge__fn__symlinks
    __bridge__fn__exec_command "$@"
    return 0
  fi
  if ! __bridge__fn__destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    exit 1
  fi
  __bridge__fn__build_and_run
  __bridge__fn__symlinks
  __bridge__fn__exec_command "$@"
}

if [[ ${__bridge__session_flag} = true ]]; then
  if [[ ${__bridge__minimal_flag} = true ]]; then
    __bridge__fn__session
  else
    __bridge__fn__session "${HOME}/.solos/.bashrc"
  fi
fi
