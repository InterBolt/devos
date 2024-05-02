#!/usr/bin/env bash

vinENTRY_DIR="${PWD}"
trap 'cd '"${vinENTRY_DIR}"'' EXIT

vinREPO_URL="https://github.com/InterBolt/solos.git"
vinUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
vinREPO_BIN_EXECUTABLE_PATH="bin/proxy.sh"
if [[ $1 = "--dev" ]]; then
  vinREPO_BIN_EXECUTABLE_PATH="bin/proxy-dev.sh"
  vinUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/dsolos"
  shift
fi
vinTMP_DIR="$(mktemp -d 2>/dev/null)"
vinTMP_SOURCE_ROOT="${vinTMP_DIR}/src"
vinSOLOS_DIR="${HOME}/.solos"
vinSOLOS_SRC_DIR="${vinSOLOS_DIR}/src"
vinSOLOS_VSCODE_BASHRC_FILE="${vinSOLOS_DIR}/vscode.bashrc"

do_clone() {
  if ! git clone "${vinREPO_URL}" "${vinTMP_SOURCE_ROOT}" >/dev/null 2>&1; then
    echo "Failed to clone ${vinREPO_URL} to ${vinTMP_SOURCE_ROOT}" >&2
    exit 1
  fi
  if [[ ! -f "${vinTMP_SOURCE_ROOT}/${vinREPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "${vinTMP_SOURCE_ROOT}/${vinREPO_BIN_EXECUTABLE_PATH} not found." >&2
    exit 1
  fi
}
do_bin_link() {
  mkdir -p "$vinSOLOS_DIR"
  if [[ ! -f "${vinSOLOS_VSCODE_BASHRC_FILE:?}" ]]; then
    {
      echo "source \"\${HOME}/.solos/src/bin/vscode-bashrc.sh\""
      echo ""
      echo "# This file is sourced inside of the docker container when the command is run."
      echo "# Add your customizations:"
    } >"${vinSOLOS_VSCODE_BASHRC_FILE}"
  fi
  rm -rf "${vinSOLOS_SRC_DIR:?}"
  mkdir -p "${vinSOLOS_SRC_DIR:?}"
  cp -r "${vinTMP_SOURCE_ROOT:?}/." "${vinSOLOS_SRC_DIR:?}" || exit 1
  if ! ln -sfv "${vinSOLOS_SRC_DIR:?}/${vinREPO_BIN_EXECUTABLE_PATH}" "${vinUSR_LOCAL_BIN_EXECUTABLE}" >/dev/null; then
    echo "Failed to link ${vinSOLOS_SRC_DIR}/${vinREPO_BIN_EXECUTABLE_PATH} to ${vinUSR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  chmod +x "${vinSOLOS_SRC_DIR:?}/${vinREPO_BIN_EXECUTABLE_PATH}"
  chmod +x "${vinUSR_LOCAL_BIN_EXECUTABLE}"
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
if ! "${vinUSR_LOCAL_BIN_EXECUTABLE}" --installer-no-tty --restricted-noop; then
  echo "Solos installation failed." >&2
  exit 1
fi
cd "${vinENTRY_DIR}" || exit 1

echo "Run \`solos --help\` to get started."
