#!/usr/bin/env bash

viENTRY_DIR="${PWD}"
trap 'cd '"${viENTRY_DIR}"'' EXIT

viREPO_URL="https://github.com/InterBolt/solos.git"
viUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
viREPO_BIN_EXECUTABLE_PATH="bin/proxy.sh"
if [[ $1 = "--dev" ]]; then
  viREPO_BIN_EXECUTABLE_PATH="bin/proxy-dev.sh"
  viUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/dsolos"
  shift
fi
viTMP_DIR="$(mktemp -d 2>/dev/null)"
viTMP_SOURCE_ROOT="${viTMP_DIR}/src"
viSOLOS_DIR="${HOME}/.solos"
viSOLOS_SRC_DIR="${viSOLOS_DIR}/src"
viSOLOS_VSCODE_BASHRC_FILE="${viSOLOS_DIR}/vscode.bashrc"

do_clone() {
  if ! git clone "${viREPO_URL}" "${viTMP_SOURCE_ROOT}" >/dev/null 2>&1; then
    echo "Failed to clone ${viREPO_URL} to ${viTMP_SOURCE_ROOT}" >&2
    exit 1
  fi
  if [[ ! -f "${viTMP_SOURCE_ROOT}/${viREPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "${viTMP_SOURCE_ROOT}/${viREPO_BIN_EXECUTABLE_PATH} not found." >&2
    exit 1
  fi
}
do_bin_link() {
  mkdir -p "$viSOLOS_DIR"
  if [[ ! -f "${viSOLOS_VSCODE_BASHRC_FILE:?}" ]]; then
    {
      echo "source \"\${HOME}/.solos/src/bin/.bashrc\""
      echo ""
      echo "# This file is sourced inside of the docker container when the command is run."
      echo "# Add your customizations:"
    } >"${viSOLOS_VSCODE_BASHRC_FILE}"
  fi
  rm -rf "${viSOLOS_SRC_DIR:?}"
  mkdir -p "${viSOLOS_SRC_DIR:?}"
  cp -r "${viTMP_SOURCE_ROOT:?}/." "${viSOLOS_SRC_DIR:?}" || exit 1
  if ! ln -sfv "${viSOLOS_SRC_DIR:?}/${viREPO_BIN_EXECUTABLE_PATH}" "${viUSR_LOCAL_BIN_EXECUTABLE}" >/dev/null; then
    echo "Failed to link ${viSOLOS_SRC_DIR}/${viREPO_BIN_EXECUTABLE_PATH} to ${viUSR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  chmod +x "${viSOLOS_SRC_DIR:?}/${viREPO_BIN_EXECUTABLE_PATH}"
  chmod +x "${viUSR_LOCAL_BIN_EXECUTABLE}"
}
if [[ "${BASH_VERSION}" < 3.1 ]]; then
  echo "SolOS requires Bash version 3.1 or greater to use. Detected ${BASH_VERSION}." >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to install SolOS on this system." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "Git is required to install SolOS on this system." >&2
  exit 1
fi
if ! do_clone; then
  echo "Solos installation failed." >&2
  exit 1
fi
if ! do_bin_link; then
  echo "Solos installation failed." >&2
  exit 1
fi
if ! "${viUSR_LOCAL_BIN_EXECUTABLE}" --installer-no-tty --restricted-noop; then
  echo "Solos installation failed." >&2
  exit 1
fi
cd "${viENTRY_DIR}" || exit 1

echo "Run \`solos --help\` to get started."
