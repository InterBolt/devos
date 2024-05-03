#!/usr/bin/env bash

# Implications of needing to run this via curl and piping to bash:
#
# To mitigate the risks of the script failing due to a network
# or escaping error, we place as much of the script's code inside a __var__main
# function as possible, global variable definitions included.
# __var__main function. By the time the main function is running, we can guarantee that
# failures will only occur due to faulty programming.

iENTRY_DIR="${PWD}"
trap 'cd '"${iENTRY_DIR}"'' EXIT

__fn__clone() {
  if ! git clone "${iREPO_URL}" "${iTMP_SOURCE_ROOT}" >/dev/null 2>&1; then
    echo "Failed to clone ${iREPO_URL} to ${iTMP_SOURCE_ROOT}" >&2
    exit 1
  fi
  if [[ ! -f "${iTMP_SOURCE_ROOT}/${iREPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "${iTMP_SOURCE_ROOT}/${iREPO_BIN_EXECUTABLE_PATH} not found." >&2
    exit 1
  fi
}
__fn__init_fs() {

}
__fn__link_bin() {
  mkdir -p "$iSOLOS_DIR"
  if [[ ! -f "${iSOLOS_VSCODE_BASHRC_FILE:?}" ]]; then
    {
      echo "source \"\${HOME}/.solos/src/bin/bashrc-container.sh\""
      echo ""
      echo "# This file is sourced inside of the docker container when the command is run."
      echo "# Add your customizations:"
    } >"${iSOLOS_VSCODE_BASHRC_FILE}"
  fi
  rm -rf "${iSOLOS_SRC_DIR:?}"
  mkdir -p "${iSOLOS_SRC_DIR:?}"
  cp -r "${iTMP_SOURCE_ROOT:?}/." "${iSOLOS_SRC_DIR:?}" || exit 1
  if ! ln -sfv "${iSOLOS_SRC_DIR:?}/${iREPO_BIN_EXECUTABLE_PATH}" "${iUSR_LOCAL_BIN_EXECUTABLE}" >/dev/null; then
    echo "Failed to link ${iSOLOS_SRC_DIR}/${iREPO_BIN_EXECUTABLE_PATH} to ${iUSR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  chmod +x "${iUSR_LOCAL_BIN_EXECUTABLE}"
}

__fn__MAIN() {
  if [[ "${BASH_VERSION}" < 3.1 ]]; then
    echo "SolOS requires Bash version 3.1 or greater to use. Detected ${BASH_VERSION}." >&2
    return 1
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to install SolOS on this system." >&2
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "Git is required to install SolOS on this system." >&2
    return 1
  fi
  if ! __fn__clone; then
    echo "Solos installation failed." >&2
    return 1
  fi
  if ! __fn__init_fs; then
    echo "Solos installation failed." >&2
    return 1
  fi
  if ! __fn__link_bin; then
    echo "Solos installation failed." >&2
    return 1
  fi
  if ! "${iUSR_LOCAL_BIN_EXECUTABLE}" --installer-no-tty --restricted-noop; then
    echo "Solos installation failed." >&2
    return 1
  fi
  echo "Run \`solos --help\` to get started."
}

if ! __fn__MAIN; then
  exit 1
fi
