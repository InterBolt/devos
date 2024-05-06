#!/usr/bin/env bash

__var__ENTRY_DIR="${PWD}"
trap 'cd '"${__var__ENTRY_DIR}"'' EXIT

__var__REPO_URL="https://github.com/InterBolt/solos.git"
__var__USR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
__var__REPO_BIN_EXECUTABLE_PATH="bin/posix.run.solos.sh"
if [[ $1 = "--dev" ]]; then
  __var__REPO_BIN_EXECUTABLE_PATH="bin/posix.run.solos-dev.sh"
  __var__USR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/dsolos"
  shift
fi
__var__TMP_DIR="$(mktemp -d 2>/dev/null)"
__var__TMP_SOURCE_ROOT="${__var__TMP_DIR}/src"
__var__SOLOS_DIR="${HOME}/.solos"
__var__SOLOS_SRC_DIR="${__var__SOLOS_DIR}/src"
__var__SOLOS_VSCODE_BASHRC_FILE="${__var__SOLOS_DIR}/.bashrc"

__fn__clone() {
  if ! git clone "${__var__REPO_URL}" "${__var__TMP_SOURCE_ROOT}" >/dev/null 2>&1; then
    echo "Failed to clone ${__var__REPO_URL} to ${__var__TMP_SOURCE_ROOT}" >&2
    exit 1
  fi
  if [[ ! -f "${__var__TMP_SOURCE_ROOT}/${__var__REPO_BIN_EXECUTABLE_PATH}" ]]; then
    echo "${__var__TMP_SOURCE_ROOT}/${__var__REPO_BIN_EXECUTABLE_PATH} not found." >&2
    exit 1
  fi
}
__fn__init_fs() {
  mkdir -p "${__var__SOLOS_DIR}" || exit 1
  mkdir -p "${__var__SOLOS_DIR}/secrets" || exit 1

  # Create the bashrc file
  if [[ ! -f "${__var__SOLOS_VSCODE_BASHRC_FILE:?}" ]]; then
    {
      echo "#!/usr/bin/env bash"
      echo ""
      echo "source \"\${HOME}/.solos/src/bin/profile/bashrc.sh\""
      echo ""
      echo "# This file is sourced inside of the docker container when the command is run."
      echo "# Add your customizations:"
    } >"${__var__SOLOS_VSCODE_BASHRC_FILE}"
  fi

  # Create the source code dir and copy the cloned repo into it.
  rm -rf "${__var__SOLOS_SRC_DIR:?}" || exit 1
  mkdir -p "${__var__SOLOS_SRC_DIR:?}" || exit 1
  cp -r "${__var__TMP_SOURCE_ROOT:?}/." "${__var__SOLOS_SRC_DIR:?}" || exit 1
}
__fn__link_bin() {
  if ! ln -sfv "${__var__SOLOS_SRC_DIR:?}/${__var__REPO_BIN_EXECUTABLE_PATH}" "${__var__USR_LOCAL_BIN_EXECUTABLE}" >/dev/null; then
    echo "Failed to link ${__var__SOLOS_SRC_DIR}/${__var__REPO_BIN_EXECUTABLE_PATH} to ${__var__USR_LOCAL_BIN_EXECUTABLE}" >&2
    exit 1
  fi
  if ! chmod +x "${__var__USR_LOCAL_BIN_EXECUTABLE}"; then
    echo "Failed to make ${__var__USR_LOCAL_BIN_EXECUTABLE} executable." >&2
    exit 1
  fi
}

__fn__MAIN() {
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
  if ! "${__var__USR_LOCAL_BIN_EXECUTABLE}" --installer-no-tty --restricted-noop; then
    echo "Solos installation failed." >&2
    return 1
  fi
  echo "Run \`solos --help\` to get started."
}

if ! __fn__MAIN; then
  exit 1
fi
