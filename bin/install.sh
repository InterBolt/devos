#!/usr/bin/env bash

viENTRY_DIR="${PWD}"
trap 'cd '"${viENTRY_DIR}"'' EXIT

# Note: in the prefix, "v" stands for variable and "i" for install.
# I chose to use this prefix because global variables in the main bin scripts
# use only the "v" prefix, which makes grepping one set of variables vs the other easy.
# I hate thinking!

viREPO_URL="https://github.com/InterBolt/solos.git"
viUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
viREPO_BIN_EXECUTABLE_PATH="bin/proxy-prod.sh"
# Don't use the restricted-* prefix because this flag is public facing
# in the install script.
if [[ $1 = "--dev" ]]; then
  viREPO_BIN_EXECUTABLE_PATH="bin/proxy-dev.sh"
  viUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/dsolos"
  shift
fi
viTMP_DIR="$(mktemp -d 2>/dev/null)"
viTMP_SOURCE_ROOT="${viTMP_DIR}/src"
viSOLOS_ROOT="${HOME}/.solos"
viSOURCE_ROOT="${viSOLOS_ROOT}/src"

do_clone() {
  if ! git clone "${viREPO_URL}" "${viTMP_SOURCE_ROOT}" >/dev/null 2>&1; then
    echo "Error: failed to clone ${viREPO_URL} to ${viTMP_SOURCE_ROOT}" >&2
    exit 1
  fi
  if [[ ! -f "${viTMP_SOURCE_ROOT}/${viREPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "Error: ${viTMP_SOURCE_ROOT}/${viREPO_BIN_EXECUTABLE_PATH} not found." >&2
    exit 1
  fi
}

do_bin_link() {
  mkdir -p "$viSOLOS_ROOT"
  rm -rf "${viSOURCE_ROOT:?}"
  mkdir -p "${viSOURCE_ROOT:?}"
  cp -r "${viTMP_SOURCE_ROOT:?}/." "${viSOURCE_ROOT:?}" || exit 1

  if ! ln -sfv "${viSOURCE_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH}" "${viUSR_LOCAL_BIN_EXECUTABLE}" >/dev/null; then
    echo "Error: failed to link ${viSOURCE_ROOT}/${viREPO_BIN_EXECUTABLE_PATH} to ${viUSR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi

  chmod +x "${viSOURCE_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH}"
  chmod +x "${viUSR_LOCAL_BIN_EXECUTABLE}"
}

# Note: this version only applies to the install script.
# Solos will always run in a predictable environment because it is
# invoked via a docker container command.
# shellcheck disable=SC2072
if [[ "${BASH_VERSION}" < 3.1 ]]; then
  echo "Error: SolOS requires Bash version 3.1 or greater to use. Detected ${BASH_VERSION}." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is required to install SolOS on this system." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required to install SolOS on this system." >&2
  exit 1
fi

if ! do_clone; then
  echo "Error: solos installation failed." >&2
  exit 1
fi

if ! do_bin_link; then
  echo "Error: solos installation failed." >&2
  exit 1
fi

if ! solos --restricted-noop; then
  echo "Error: solos installation failed." >&2
  exit 1
fi

cd "${viENTRY_DIR}" || exit 1

echo "Run \`solos --help\` to get started with SolOS"
