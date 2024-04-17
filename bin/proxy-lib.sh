#!/usr/bin/env bash

# Note: in the prefix, "v" stands for variable and "i" for install.
# I chose to use this prefix because global variables in the main bin scripts
# use only the "v" prefix, which makes grepping one set of variables vs the other easy.
# I hate thinking!
vpVOLUME_SOURCE="${HOME}/.solos"

vpENTRY_DIR="${PWD}"
trap 'cd '"${vpENTRY_DIR}"'' EXIT

# check if the readlink command exists
if ! command -v readlink >/dev/null 2>&1; then
  echo "Error: \`readlink\` must exist on your system." >&2
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
vpVOLUME_HOST_PATH="${vpVOLUME_SOURCE}/.host_path"
if [[ -f /.dockerenv ]] && [[ ! -f ${vpVOLUME_HOST_PATH} ]]; then
  echo "Error: the .host_path file was not found in the .solos directory." >&2
  echo "This file is required to run SolOS within a Docker container." >&2
  exit 1
fi
if [[ -f /.dockerenv ]]; then
  vpVOLUME_SOURCE="$(cat "${vpVOLUME_HOST_PATH}")"
fi
vpVOLUME_MOUNTED="/root/.solos"
vpDOCKER_BASE_IMAGE="solos:base"
vpDOCKER_CLI_IMAGE="soloscli:$(git rev-parse --short HEAD | cut -c1-7 || echo "")"
vpFROM_INSTALL_CHECK=false
for entry_arg in "$@"; do
  if [[ $entry_arg = "--postinstall" ]]; then
    set -- "${@/--postinstall/}"
    vpFROM_INSTALL_CHECK=true
  fi
done

docker_build_base() {
  if ! docker build -q -t "${vpDOCKER_BASE_IMAGE}" -f Dockerfile.base . >/dev/null; then
    echo "Error: failed to build the docker image." >&2
    exit 1
  fi

}

docker_build_cli() {
  if ! docker build -q -t "${vpDOCKER_CLI_IMAGE}" -f Dockerfile.cli . >/dev/null; then
    echo "Error: failed to build the docker image." >&2
    exit 1
  fi
}

docker_run_cli() {
  local args=(
    --rm
    -v
    "${vpVOLUME_SOURCE}:${vpVOLUME_MOUNTED}"
    -v
    /var/run/docker.sock:/var/run/docker.sock
    "${vpDOCKER_CLI_IMAGE}"
    /bin/bash
    "$@"
  )

  # When the CLI is first installed, avoid docker run's -t option
  # It causes a TTY error, likely because it's run from a curled bash script
  # without the same stdin/out assumptions.
  if [[ ${vpFROM_INSTALL_CHECK} = true ]]; then
    if ! docker run -i "${args[@]}"; then
      echo "Unexpected error: failed to run the docker image." >&2
      exit 1
    fi
  else
    if ! docker run -it "${args[@]}"; then
      echo "Unexpected error: failed to run the docker image." >&2
      exit 1
    fi
  fi
}

main() {
  if [[ -f ${vpVOLUME_SOURCE} ]]; then
    echo "Error: a filed called .solos was detected in your home directory." >&2
    echo "SolOS cannot create a dir named .solos in your home directory." >&2
    exit 1
  fi
  mkdir -p "${vpVOLUME_SOURCE}"
  echo "${vpVOLUME_SOURCE}" >"${vpVOLUME_HOST_PATH}"
  # The docker commands are just simpler if we cd in the launch directory
  if ! cd bin/launch; then
    echo "Unexpected error: could not cd into bin/launch" >&2
    exit 1
  fi
  docker_build_base
  docker_build_cli
  docker_run_cli "$@"
}
