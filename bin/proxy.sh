#!/usr/bin/env bash

FROM_INSTALL_CHECK=false
for entry_arg in "$@"; do
  if [[ $entry_arg = "--install-check" ]]; then
    set -- "${@/--install-check/}"
    FROM_INSTALL_CHECK=true
  fi
done

# check if the readlink command exists
if ! command -v readlink >/dev/null 2>&1; then
  echo "Error: readlink must exist on your system." >&2
  exit 1
fi

SYMLINKED_PATH="$(readlink -f "$0" || echo "")"

if [[ -z ${SYMLINKED_PATH} ]]; then
  echo "Error: could not resolve the symlink for $0." >&2
  exit 1
fi

BIN_DIR="$(dirname "${SYMLINKED_PATH}")"
REPO_DIR="$(dirname "${BIN_DIR}")"

if ! cd "${REPO_DIR}"; then
  echo "Unexpected error: could not cd into ${REPO_DIR}" >&2
  exit 1
fi

VOLUME_MOUNTED="/root/.solos"
VOLUME_SOURCE="${HOME}/.solos"
DOCKER_IMAGE_NAME="solos-bin"
DOCKER_IMAGE_TAG="$(git rev-parse --short HEAD | cut -c1-7 || echo "")"

docker_build_cached() {
  if ! docker build -q -t "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" bin >/dev/null; then
    echo "Error: failed to build the docker image." >&2
    exit 1
  fi
}

docker_build_fresh() {
  if ! docker build --no-cache -t "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" bin; then
    echo "Error: failed to build the docker image." >&2
    exit 1
  fi
}

docker_run_cli() {
  if [[ ${FROM_INSTALL_CHECK} = true ]]; then
    if ! docker run --rm -i \
      -v "${VOLUME_SOURCE}:${VOLUME_MOUNTED}" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" \
      /bin/bash "$@"; then
      echo "Unexpected error: failed to run the docker image." >&2
      exit 1
    fi
  else
    if ! docker run --rm -it \
      -v "${VOLUME_SOURCE}:${VOLUME_MOUNTED}" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" \
      /bin/bash "$@"; then
      echo "Unexpected error: failed to run the docker image." >&2
      exit 1
    fi
  fi
}

main() {
  if [[ -f ${VOLUME_SOURCE} ]]; then
    echo "Error: a filed called .solos was detected in your home directory." >&2
    echo "SolOS cannot create a dir named .solos in your home directory." >&2
    exit 1
  fi
  mkdir -p "${VOLUME_SOURCE}"
  local found_tag="$(docker images "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" --format "{{.Tag}}")"
  if [[ -z ${found_tag} ]]; then
    docker_build_fresh
  else
    docker_build_cached
  fi
  docker_run_cli "$@"
}

main "$@"
