#!/usr/bin/env bash

vproxyENTRY_DIR="${PWD}"

cd "${HOME}" || exit 1

vproxyVOLUME_ROOT="${HOME}/.solos"
vproxyREPO_LAUNCH_DIR="${vproxyVOLUME_ROOT}/src/bin/launch"
vproxySYMLINKED_PATH="$(readlink -f "$0" || echo "${HOME}/.solos/src/bin/proxy.sh")"
if [[ -z ${vproxySYMLINKED_PATH} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
vproxyBIN_DIR="$(dirname "${vproxySYMLINKED_PATH}")"
vproxyREPO_DIR="$(dirname "${vproxyBIN_DIR}")"
if ! cd "${vproxyREPO_DIR}"; then
  echo "Unexpected error: could not cd into ${vproxyREPO_DIR}" >&2
  exit 1
fi
vproxyVOLUME_CONFIG_HOSTFILE="${vproxyVOLUME_ROOT}/config/host"
vproxyVOLUME_MOUNTED="/root/.solos"
vproxyGIT_HASH="$(cd "${vproxyVOLUME_ROOT}/src" && git rev-parse --short HEAD | cut -c1-7 || echo "")"
vproxyINSTALLER_NO_TTY_FLAG=false
__next_args=()
for entry_arg in "$@"; do
  if [[ $entry_arg = "--installer-no-tty" ]]; then
    vproxyINSTALLER_NO_TTY_FLAG=true
  else
    __next_args+=("$entry_arg")
  fi
done
set -- "${__next_args[@]}" || exit 1

test_exec() {
  local args=()
  if [[ ${vproxyINSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i "${vproxyGIT_HASH}" echo "")
  else
    args=(-it "${vproxyGIT_HASH}" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null &>/dev/null; then
    return 1
  fi
  return 0
}

exec_cmd() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${vproxyINSTALLER_NO_TTY_FLAG} = true ]]; then
    args=(-i -w "${container_ctx}" "${vproxyGIT_HASH}")
  else
    args=(-it -w "${container_ctx}" "${vproxyGIT_HASH}")
  fi
  docker exec "${args[@]}" /bin/bash --rcfile /root/.solos/.bashrc -i -c "${*}"
}

run_cmd_in_docker() {
  if test_exec; then
    exec_cmd "$@"
    return 0
  fi

  # Initalize the home/.solos dir if it's not already there.
  if [[ -f ${vproxyVOLUME_ROOT} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${vproxyVOLUME_CONFIG_HOSTFILE}")"
  echo "${HOME}" >"${vproxyVOLUME_CONFIG_HOSTFILE}"

  # Build the base and cli images.
  if ! docker build -t "solos:base" -f "${vproxyREPO_LAUNCH_DIR}/Dockerfile.base" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    sleep 10
    exit 1
  fi
  if ! docker build -t "solos-cli:${vproxyGIT_HASH}" -f "${vproxyREPO_LAUNCH_DIR}/Dockerfile.cli" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    sleep 10
    exit 1
  fi
  local shared_docker_run_args=(
    --name "${vproxyGIT_HASH}"
    -d
    -v /var/run/docker.sock:/var/run/docker.sock
    -v "${vproxyVOLUME_ROOT}:${vproxyVOLUME_MOUNTED}"
    -v /usr/local/bin/solos:/usr/local/bin/solos
    -v /usr/local/bin/dsolos:/usr/local/bin/dsolos
    "solos-cli:${vproxyGIT_HASH}"
  )
  if [[ ${vproxyINSTALLER_NO_TTY_FLAG} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! test_exec; do
    sleep .2
  done
  exec_cmd "$@"
}
