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

do_check() {
  #
  # Only debian users are allowed to run the script without docker.
  # I made the decision to only support debian a long time ago and
  # don't intend to change that.
  #
  # If docker doesn't exist on an unsupported system, we don't even bother
  # trying to install SolOS. Better off catching it early and asking the user to re-install
  # once ready.
  #
  local requires_docker=false
  if [[ -z $BASH_VERSION ]]; then
    echo "unsupported shell. try again with Bash." >&2
    exit 1
  fi
  if ! command -v lsb_release -i >/dev/null 2>&1; then
    requires_docker=true
  elif [[ $(lsb_release -i -s 2>/dev/null) != "Debian" ]]; then
    requires_docker=true
  fi
  if [[ $requires_docker = true ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      echo "docker is required to install SolOS on this system." >&2
      exit 1
    fi
  fi
}

do_clone() {
  git clone "${viREPO_URL}" "${viTMP_REPO}" >/dev/null 2>&1
  if [[ ! -f "${viTMP_REPO}/${viREPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "${viTMP_REPO}/${viREPO_BIN_EXECUTABLE_PATH} not found." >&2
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
    echo "failed to link ${viSTATIC_MY_CONFIG_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH} to ${viUSR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  #
  # Ensure they're executable for extra safety.
  #
  chmod +x "${viSTATIC_MY_CONFIG_ROOT:?}/${viREPO_BIN_EXECUTABLE_PATH}"
  chmod +x "${viUSR_LOCAL_BIN_EXECUTABLE}"
}

if ! do_check; then
  echo "solos installation failed." >&2
  exit 1
fi

if ! do_clone; then
  echo "solos installation failed." >&2
  exit 1
fi

if ! do_bin_link; then
  echo "solos installation failed." >&2
  exit 1
fi

echo "successfully installed SolOS."
echo "run 'solos --help' to get started"
