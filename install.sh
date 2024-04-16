#!/usr/bin/env bash

viENTRY_DIR="${PWD}"
trap 'cd '"${viENTRY_DIR}"'' EXIT

#
# Note: in the prefix, "v" stands for variable and "i" for install.
# I chose to use this prefix because global variables in the main bin scripts
# use only the "v" prefix, which makes grepping one set of variables vs the other easy.
# I hate thinking!
#
viTMP_DIR="$(mktemp -d 2>/dev/null)"
viTMP_REPO="${viTMP_DIR}/solos"
viREPO_URL="https://github.com/InterBolt/solos.git"
viUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
viREPO_BIN_EXECUTABLE_PATH="bin/proxy.sh"
viCONFIG_ROOT="$HOME/.solos"
viSOURCE_ROOT="${viCONFIG_ROOT}/source"

do_clone() {
  if ! git clone "${viREPO_URL}" "${viTMP_REPO}" >/dev/null 2>&1; then
    echo "Error: failed to clone ${viREPO_URL} to ${viTMP_REPO}" >&2
    exit 1
  fi
  if [[ ! -f "${viTMP_REPO}/${viREPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "Error: ${viTMP_REPO}/${viREPO_BIN_EXECUTABLE_PATH} not found." >&2
    exit 1
  fi
}

do_bin_link() {
  #
  # Important: the remainder of the script assumes we're in the bin folder.
  #
  cd "${viTMP_REPO}/bin" || exit 1
  #
  # Fundamentally, we must clone the repo before we can source the static.sh file.
  #
  mkdir -p "$viCONFIG_ROOT"
  #
  # Overwrite the bin files stored in the config folder.
  #
  rm -rf "${viSOURCE_ROOT:?}"
  mkdir -p "${viSOURCE_ROOT:?}"
  cp -r "${viTMP_REPO}/." "${viSOURCE_ROOT:?}" || exit 1
  #
  # Use linking rather than copying for the simplest possible update process.
  #
  if ! ln -sfv "${viSOURCE_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH}" "${viUSR_LOCAL_BIN_EXECUTABLE}" >/dev/null; then
    echo "Error: failed to link ${viSOURCE_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH} to ${viUSR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  #
  # Ensure they're executable for extra safety.
  #
  chmod +x "${viSOURCE_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH}"
  chmod +x "${viUSR_LOCAL_BIN_EXECUTABLE}"
}

# Normally can't compare decimals, but bash comparisons like this work for semvar.
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

if ! solos --noop; then
  echo "Error: solos installation failed." >&2
  exit 1
fi

cd "${viENTRY_DIR}" || exit 1

echo "Run \`solos --help\` to get started with SolOS"
