#!/usr/bin/env bash

# Note: in the prefix, "v" stands for variable and "i" for install.
# I chose to use this prefix because global variables in the main bin scripts
# use only the "v" prefix, which makes grepping one set of variables vs the other easy.
# I hate thinking!

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
vpVOLUME_MOUNTED="/root/.solos"
vpVOLUME_SOURCE="${HOME}/.solos"
vpDOCKER_IMAGE="solos:$(git rev-parse --short HEAD | cut -c1-7 || echo "")"
vpFROM_INSTALL_CHECK=false
for entry_arg in "$@"; do
  if [[ $entry_arg = "--postinstall" ]]; then
    set -- "${@/--postinstall/}"
    vpFROM_INSTALL_CHECK=true
  fi
done

docker_build_cached() {
  if ! docker build -q -t "${vpDOCKER_IMAGE}" bin >/dev/null; then
    echo "Error: failed to build the docker image." >&2
    exit 1
  fi
}

docker_build_fresh() {
  if ! docker build --no-cache -t "${vpDOCKER_IMAGE}" bin; then
    echo "Error: failed to build the docker image." >&2
    exit 1
  fi
}

docker_run_cli() {
  local args=(
    -v
    "${vpVOLUME_SOURCE}:${vpVOLUME_MOUNTED}"
    -v
    /var/run/docker.sock:/var/run/docker.sock
    "${vpDOCKER_IMAGE}"
    /bin/bash
  )

  # When the CLI is first installed, avoid docker run's -t option
  # It causes a TTY error, likely because it's run from a curled bash script
  # without the same stdin/out assumptions.
  if [[ ${vpFROM_INSTALL_CHECK} = true ]]; then
    if ! docker run --rm -i "${args[@]}" "$@"; then
      echo "Unexpected error: failed to run the docker image." >&2
      exit 1
    fi
  else
    if ! docker run --rm -it "${args[@]}" "$@"; then
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
  local found_tag="$(docker images "${vpDOCKER_IMAGE}" --format "{{.Tag}}")"
  if [[ -z ${found_tag} ]]; then
    docker_build_fresh
  else
    docker_build_cached
  fi
  docker_run_cli "$@"
}
