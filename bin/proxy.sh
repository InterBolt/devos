#!/usr/bin/env bash

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

if ! cd "${BIN_DIR}"; then
  echo "Unexpected error: could not cd into ${BIN_DIR}" >&2
  exit 1
fi

VOLUME_MOUNTED="/root/.solos"
VOLUME_SOURCE="${HOME}/.solos"
DOCKER_IMAGE_NAME="solos-bin"
DOCKER_IMAGE_TAG="$(git rev-parse --short HEAD | cut -c1-7 || echo "")"

get_repo_path() {
  local repo_path="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -z ${repo_path} ]]; then
    echo "Error: this script must be run from within the solos repository." >&2
    exit 1
  fi
  if ! cd "${repo_path}"; then
    echo "Error: could not cd into the solos repository." >&2
    exit 1
  fi
  echo "${repo_path}"
}

validate_env() {
  if [[ -z ${BASH_VERSION} ]]; then
    echo "unsupported shell detected. try again with Bash." >&2
    exit 1
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed." >&2
    exit 1
  fi
}

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
  if ! docker run --rm -it \
    -v "${VOLUME_SOURCE}:${VOLUME_MOUNTED}" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" \
    /bin/bash "$@" </dev/null; then
    echo "Unexpected error: failed to run the docker image." >&2
    exit 1
  fi
}

main() {
  cd "$(get_repo_path)" || exit 1
  if [[ -f ${VOLUME_SOURCE} ]]; then
    echo "Error: a filed called .solos was detected in your home directory." >&2
    echo "SolOS cannot create a dir named .solos in your home directory." >&2
    exit 1
  fi
  mkdir -p "${VOLUME_SOURCE}"
  validate_env
  local found_tag="$(docker images "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" --format "{{.Tag}}")"
  if [[ -z ${found_tag} ]]; then
    docker_build_fresh
  else
    docker_build_cached
  fi
  docker_run_cli "$@"
}

main "$@"
