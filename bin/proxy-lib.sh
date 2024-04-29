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
vpVOLUME_HOST="${vpVOLUME_ROOT}/config/host"
if [[ -f /.dockerenv ]] && [[ ! -f ${vpVOLUME_HOST} ]]; then
  echo "The \`.host_path\` file was not found in the .solos directory." >&2
  echo "This file is required to run SolOS within a Docker container." >&2
  exit 1
fi
if [[ -f /.dockerenv ]]; then
  vpVOLUME_ROOT="$(cat "${vpVOLUME_HOST}")/.solos"
fi
vpVOLUME_MOUNTED="/root/.solos"
vpDOCKER_BASE_IMAGE="solos:base"
vpDOCKER_CLI_IMAGE="soloscli:$(git rev-parse --short HEAD | cut -c1-7 || echo "")"
vpINSTALLER_NO_TTY_FLAG=false
for entry_arg in "$@"; do
  if [[ $entry_arg = "--installer-no-tty" ]]; then
    set -- "${@/--installer-no-tty/}"
    vpINSTALLER_NO_TTY_FLAG=true
  fi
done

# Tells us where in the .solos directory we are.
# If we're anywhere else, it's empty.
echo_ctx() {
  local supplied_pwd="${1}"
  local volume_ctx="${supplied_pwd#"${HOME}"/.solos/}"
  if [[ "${volume_ctx}" != "${HOME}/.solos" ]]; then
    volume_ctx=".solos/${volume_ctx}"
    if [[ "${volume_ctx}" == *//* ]]; then
      volume_ctx=""
    fi
  else
    volume_ctx=".solos"
  fi
  echo "${volume_ctx}"
}

prevent_use_outside_home_dir() {
  local entry_dir="$1"
  local pwd_rel_to_home="${entry_dir/${HOME}/}"
  if [[ "${pwd_rel_to_home}" == "${entry_dir}" ]]; then
    echo "Solos must be run from your home directory." >&2
    exit 1
  fi
}

run_solos_in_docker() {
  local verbose="${VERBOSE:-0}"
  if [[ ! "${verbose}" =~ ^[01]$ ]]; then
    echo "VERBOSE must be set to 0 (default) or 1." >&2
    exit 1
  fi
  local entry_dir="$1"
  prevent_use_outside_home_dir "${entry_dir}"
  shift

  # Initalize the home/.solos dir if it's not already there.
  if [[ -f ${vpVOLUME_ROOT} ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    echo "This namespace is required for solos. (SolOS creates a ~/.solos dir)" >&2
    exit 1
  fi
  mkdir -p "${vpVOLUME_ROOT}"
  echo "${HOME}" >"${vpVOLUME_HOST}"

  # Build the base and cli images.
  if ! docker build --build-arg="VERBOSE=${verbose}" -q -t "${vpDOCKER_BASE_IMAGE}" -f "${vpREPO_LAUNCH_DIR}/Dockerfile.base" . >/dev/null; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  if ! docker build --build-arg="VERBOSE=${verbose}" -q -t "${vpDOCKER_CLI_IMAGE}" -f "${vpREPO_LAUNCH_DIR}/Dockerfile.cli" . >/dev/null; then
    echo "Unexpected error: failed to build the docker image." >&2
    exit 1
  fi
  # Notes:
  # - The --rm flag will remove the container on exit so that this is ephemeral.
  # - The two volumes are:
  #     1) the .solos dir which contains SolOS source code, various internal state,
  #        and all of the SolOS projects for a user
  #     2) the docker socket file on the host, which ensures containers created within containers
  #        are siblings, not children. Lot's of reasons why...DYOR.
  # - We put the arguments into a shared array because it's easier to read the conditional which
  #   determines whether to use the -t flag or not. When SolOS is first installed, the script is
  #   run via curl's stdout, which causes some TTY errors. This is a workaround.
  local shared_docker_run_args=(
    --rm
    -v
    "${vpVOLUME_ROOT}:${vpVOLUME_MOUNTED}"
    -v
    /var/run/docker.sock:/var/run/docker.sock
    "${vpDOCKER_CLI_IMAGE}"
    /bin/bash
  )
  if [[ ${vpINSTALLER_NO_TTY_FLAG} = true ]]; then
    if ! docker run -i "${shared_docker_run_args[@]}" "$@"; then
      echo "Unexpected error: failed to run the docker image." >&2
      exit 1
    fi
  else
    if ! docker run -it "${shared_docker_run_args[@]}" "$@"; then
      exit 1
    fi
  fi
}
