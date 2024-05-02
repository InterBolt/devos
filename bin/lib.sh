#!/usr/bin/env bash

__LIB_ENTRY_DIR="${PWD}"

cd "${HOME}" || exit 1

__LIB_VOLUME_ROOT="${HOME}/.solos"
__LIB_REPO_LAUNCH_DIR="${__LIB_VOLUME_ROOT}/src/bin/launch"
__LIB_SYMLINKED_PATH="$(readlink -f "$0" || echo "${HOME}/.solos/src/bin/solos.sh")"
if [[ -z ${__LIB_SYMLINKED_PATH} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
__LIB_BIN_DIR="$(dirname "${__LIB_SYMLINKED_PATH}")"
__LIB_REPO_DIR="$(dirname "${__LIB_BIN_DIR}")"
if ! cd "${__LIB_REPO_DIR}"; then
  echo "Unexpected error: could not cd into ${__LIB_REPO_DIR}" >&2
  exit 1
fi
__LIB_VOLUME_CONFIG_HOSTFILE="${__LIB_VOLUME_ROOT}/config/host"
__LIB_VOLUME_MOUNTED="/root/.solos"
__LIB_GIT_HASH="$(cd "${__LIB_VOLUME_ROOT}/src" && git rev-parse --short HEAD | cut -c1-7 || echo "")"
__LIB_INSTALLER_NO_TTY_FLAG=false
__LIB_next_args=()
for entry_arg in "$@"; do
  if [[ $entry_arg = "--installer-no-tty" ]]; then
    __LIB_INSTALLER_NO_TTY_FLAG=true
  else
    __LIB_next_args+=("$entry_arg")
  fi
done
set -- "${__LIB_next_args[@]}" || exit 1

__test() {
  local args=()
  if [[ ${__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i "${__LIB_GIT_HASH}" echo "")
  else
    args=(-it "${__LIB_GIT_HASH}" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null &>/dev/null; then
    return 1
  fi
  return 0
}

__exec() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "${__LIB_GIT_HASH}")
  else
    args=(-it -w "${container_ctx}" "${__LIB_GIT_HASH}")
  fi
  docker exec "${args[@]}" /bin/bash --rcfile /root/.solos/.bashrc -i -c "${*}"
}

containerized_run() {
  if __test; then
    __exec "$@"
    return 0
  fi

  # Initalize the home/.solos dir if it's not already there.
  if [[ -f ${__LIB_VOLUME_ROOT} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__LIB_VOLUME_CONFIG_HOSTFILE}")"
  echo "${HOME}" >"${__LIB_VOLUME_CONFIG_HOSTFILE}"

  # Build the base and cli images.
  if ! docker build -t "solos:base" -f "${__LIB_REPO_LAUNCH_DIR}/Dockerfile.base" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    sleep 10
    exit 1
  fi
  if ! docker build -t "solos-cli:${__LIB_GIT_HASH}" -f "${__LIB_REPO_LAUNCH_DIR}/Dockerfile.cli" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    sleep 10
    exit 1
  fi
  local shared_docker_run_args=(
    --name "${__LIB_GIT_HASH}"
    -d
    -v /var/run/docker.sock:/var/run/docker.sock
    -v "${__LIB_VOLUME_ROOT}:${__LIB_VOLUME_MOUNTED}"
    -v /usr/local/bin/solos:/usr/local/bin/solos
    -v /usr/local/bin/dsolos:/usr/local/bin/dsolos
    "solos-cli:${__LIB_GIT_HASH}"
  )
  if [[ ${__LIB_INSTALLER_NO_TTY_FLAG} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! __test; do
    sleep .2
  done
  __exec "$@"
}
