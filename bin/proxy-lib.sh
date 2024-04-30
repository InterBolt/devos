#!/usr/bin/env bash

cd "${HOME}" || exit 1

# Note: in the prefix, "v" stands for variable and "i" for install.
# I chose to use this prefix because global variables in the main bin scripts
# use only the "v" prefix, which makes grepping one set of variables vs the other easy.
# I hate thinking!

vpVOLUME_ROOT="${HOME}/.solos"
vpREPO_LAUNCH_DIR="${vpVOLUME_ROOT}/src/bin/launch"
vpENTRY_DIR="${PWD}"
trap 'cd '"${vpENTRY_DIR}"'' EXIT
# check if the readlink command exists
if ! command -v readlink >/dev/null 2>&1; then
  echo "\`readlink\` must exist on your system." >&2
  exit 1
fi
vpSYMLINKED_PATH="$(readlink -f "$0" || echo "")"
if [[ -z ${vpSYMLINKED_PATH} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
vpBIN_DIR="$(dirname "${vpSYMLINKED_PATH}")"
vpREPO_DIR="$(dirname "${vpBIN_DIR}")"
if ! cd "${vpREPO_DIR}"; then
  echo "Unexpected error: could not cd into ${vpREPO_DIR}" >&2
  exit 1
fi
vpVOLUME_CONFIG_HOSTFILE="${vpVOLUME_ROOT}/config/host"
if [[ -f /.dockerenv ]] && [[ ! -f ${vpVOLUME_CONFIG_HOSTFILE} ]]; then
  echo "The \`.host_path\` file was not found in the .solos directory." >&2
  echo "This file is required to run SolOS within a Docker container." >&2
  exit 1
fi
if [[ -f /.dockerenv ]]; then
  vpVOLUME_ROOT="$(cat "${vpVOLUME_CONFIG_HOSTFILE}")/.solos"
fi
vpVOLUME_MOUNTED="/root/.solos"
vpGIT_HASH="$(git rev-parse --short HEAD | cut -c1-7 || echo "")"
vpINSTALLER_NO_TTY_FLAG=false
for entry_arg in "$@"; do
  if [[ $entry_arg = "--installer-no-tty" ]]; then
    set -- "${@/--installer-no-tty/}"
    vpINSTALLER_NO_TTY_FLAG=true
  fi
done

test_exec() {
  local args=()
  if [[ ${vpINSTALLER_NO_TTY_FLAG} = true ]]; then
      if docker exec -i "${vpGIT_HASH}" echo "" &>/dev/null; then
        return 0
      else
        return 1
      fi
  else
      if docker exec -i "${vpGIT_HASH}" echo "" &>/dev/null; then
        return 0
      else
        return 1
      fi
  fi
}

exec_solos() {
  docker exec -it "${vpGIT_HASH}" /root/.solos/src/bin/solos.sh "$@"
}

run_solos_in_docker() {
  local entry_dir="$1"
  shift
  if test_exec; then
    exec_solos "$@"
    return 0
  fi
  # Initalize the home/.solos dir if it's not already there.
  if [[ -f ${vpVOLUME_ROOT} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${vpVOLUME_CONFIG_HOSTFILE}")"
  echo "${HOME}" >"${vpVOLUME_CONFIG_HOSTFILE}"

  # Build the base and cli images.
  if ! docker build -t "solos:base" -f "${vpREPO_LAUNCH_DIR}/Dockerfile.base" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  if ! docker build -t "solos-cli:${vpGIT_HASH}" -f "${vpREPO_LAUNCH_DIR}/Dockerfile.cli" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  local shared_docker_run_args=(
    --name
    "${vpGIT_HASH}"
    -d
    -v
    "${vpVOLUME_ROOT}:${vpVOLUME_MOUNTED}"
    -v
    /var/run/docker.sock:/var/run/docker.sock
    "solos-cli:${vpGIT_HASH}"
  )
  if [[ ${vpINSTALLER_NO_TTY_FLAG} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! test_exec; do
    sleep .2
  done
  exec_solos "$@"
}
