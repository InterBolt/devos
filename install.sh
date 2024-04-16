#!/usr/bin/env bash

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
viSTATIC_MY_CONFIG_ROOT=""

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
  mkdir -p "$viSTATIC_MY_CONFIG_ROOT"
  #
  # Overwrite the bin files stored in the config folder.
  #
  rm -rf "${viSTATIC_MY_CONFIG_ROOT:?}/bin"
  mkdir -p "${viSTATIC_MY_CONFIG_ROOT:?}/bin"
  cp -r "${viTMP_REPO}/bin/." "${viSTATIC_MY_CONFIG_ROOT:?}/bin"
  #
  # Use linking rather than copying for the simplest possible update process.
  #
  if ! ln -sfv "${viSTATIC_MY_CONFIG_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH}" "${viUSR_LOCAL_BIN_EXECUTABLE}"; then
    echo "Error: failed to link ${viSTATIC_MY_CONFIG_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH} to ${viUSR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  #
  # Ensure they're executable for extra safety.
  #
  chmod +x "${viSTATIC_MY_CONFIG_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH}"
  chmod +x "${viUSR_LOCAL_BIN_EXECUTABLE}"
}

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

solos --noop
echo "Run \`solos --help\` to get started with SolOS"
