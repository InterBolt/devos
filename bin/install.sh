#!/usr/bin/env bash

__ENTRY_DIR="${PWD}"
trap 'cd '"${__ENTRY_DIR}"'' EXIT

__REPO_URL="https://github.com/InterBolt/solos.git"
__USR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
__REPO_BIN_EXECUTABLE_PATH="bin/solos.sh"
if [[ $1 = "--dev" ]]; then
  __REPO_BIN_EXECUTABLE_PATH="bin/solos-dev.sh"
  __USR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/dsolos"
  shift
fi
__TMP_DIR="$(mktemp -d 2>/dev/null)"
__TMP_SOURCE_ROOT="${__TMP_DIR}/src"
__SOLOS_DIR="${HOME}/.solos"
__SOLOS_SRC_DIR="${__SOLOS_DIR}/src"
__SOLOS_VSCODE_BASHRC_FILE="${__SOLOS_DIR}/vscode.bashrc"

__clone() {
  if ! git clone "${__REPO_URL}" "${__TMP_SOURCE_ROOT}" >/dev/null 2>&1; then
    echo "Failed to clone ${__REPO_URL} to ${__TMP_SOURCE_ROOT}" >&2
    exit 1
  fi
  if [[ ! -f "${__TMP_SOURCE_ROOT}/${__REPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "${__TMP_SOURCE_ROOT}/${__REPO_BIN_EXECUTABLE_PATH} not found." >&2
    exit 1
  fi
}
__link_bin() {
  mkdir -p "$__SOLOS_DIR"
  if [[ ! -f "${__SOLOS_VSCODE_BASHRC_FILE:?}" ]]; then
    {
      echo "source \"\${HOME}/.solos/src/bin/bashrc-container.sh\""
      echo ""
      echo "# This file is sourced inside of the docker container when the command is run."
      echo "# Add your customizations:"
    } >"${__SOLOS_VSCODE_BASHRC_FILE}"
  fi
  rm -rf "${__SOLOS_SRC_DIR:?}"
  mkdir -p "${__SOLOS_SRC_DIR:?}"
  cp -r "${__TMP_SOURCE_ROOT:?}/." "${__SOLOS_SRC_DIR:?}" || exit 1
  if ! ln -sfv "${__SOLOS_SRC_DIR:?}/${__REPO_BIN_EXECUTABLE_PATH}" "${__USR_LOCAL_BIN_EXECUTABLE}" >/dev/null; then
    echo "Failed to link ${__SOLOS_SRC_DIR}/${__REPO_BIN_EXECUTABLE_PATH} to ${__USR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  chmod +x "${__SOLOS_SRC_DIR:?}/${__REPO_BIN_EXECUTABLE_PATH}"
  chmod +x "${__USR_LOCAL_BIN_EXECUTABLE}"
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
if ! __clone; then
  echo "Solos installation failed." >&2
  exit 1
fi
if ! __link_bin; then
  echo "Solos installation failed." >&2
  exit 1
fi
if ! "${__USR_LOCAL_BIN_EXECUTABLE}" --installer-no-tty --restricted-noop; then
  echo "Solos installation failed." >&2
  exit 1
fi
cd "${__ENTRY_DIR}" || exit 1

echo "Run \`solos --help\` to get started."
