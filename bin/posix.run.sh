#!/usr/bin/env bash

__var__LIB_ENTRY_DIR="${PWD}"

cd "${HOME}" || exit 1

__var__LIB_VOLUME_ROOT="${HOME}/.solos"
__var__LIB_REPO_LAUNCH_DIR="${__var__LIB_VOLUME_ROOT}/src/bin/launch"
__var__LIB_SYMLINKED_PATH="$(readlink -f "$0" || echo "${HOME}/.solos/src/bin/solos.sh")"
if [[ -z ${__var__LIB_SYMLINKED_PATH} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
__var__LIB_BIN_DIR="$(dirname "${__var__LIB_SYMLINKED_PATH}")"
__var__LIB_REPO_DIR="$(dirname "${__var__LIB_BIN_DIR}")"
if ! cd "${__var__LIB_REPO_DIR}"; then
  echo "Unexpected error: could not cd into ${__var__LIB_REPO_DIR}" >&2
  exit 1
fi
__var__LIB_VOLUME_CONFIG_HOSTFILE="${__var__LIB_VOLUME_ROOT}/config/host"
__var__LIB_VOLUME_MOUNTED="/root/.solos"
__var__LIB_INSTALLER_NO_TTY_FLAG=false
__var__LIB_next_args=()
for entry_arg in "$@"; do
  if [[ $entry_arg = "--installer-no-tty" ]]; then
    __var__LIB_INSTALLER_NO_TTY_FLAG=true
  else
    __var__LIB_next_args+=("$entry_arg")
  fi
done
set -- "${__var__LIB_next_args[@]}" || exit 1

__fn__hash() {
  git -C "${__var__LIB_VOLUME_ROOT}/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}

__fn__test() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__var__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__fn__hash)" echo "")
  else
    args=(-it -w "${container_ctx}" "$(__fn__hash)" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null &>/dev/null; then
    return 1
  fi
  return 0
}

__fn__exec() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__var__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__fn__hash)")
  fi
  docker exec "${args[@]}" /bin/bash --rcfile /root/.solos/.bashrc -i -c "${*}"
}

__fn__run() {
  if __fn__test; then
    __fn__exec "$@"
    return 0
  fi

  # Initalize the home/.solos dir if it's not already there.
  if [[ -f ${__var__LIB_VOLUME_ROOT} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__var__LIB_VOLUME_CONFIG_HOSTFILE}")"
  echo "${HOME}" >"${__var__LIB_VOLUME_CONFIG_HOSTFILE}"
  # Build the base and cli images.
  if ! docker build -t "solos:base" -f "${__var__LIB_REPO_LAUNCH_DIR}/Dockerfile.base" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    sleep 10
    exit 1
  fi
  if ! docker build -t "solos-cli:$(__fn__hash)" -f "${__var__LIB_REPO_LAUNCH_DIR}/Dockerfile.cli" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    sleep 10
    exit 1
  fi
  local shared_docker_run_args=(
    --name "$(__fn__hash)"
    -d
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${__var__LIB_VOLUME_ROOT}:${__var__LIB_VOLUME_MOUNTED}"
    "solos-cli:$(__fn__hash)"
  )
  if [[ ${__var__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! __fn__test; do
    sleep .2
  done
  __fn__exec "$@"
}
