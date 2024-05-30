#!/usr/bin/env bash

# This script must run and define everything within a single "main" function.
# This is because we expect the user to run this via a piped `curl script_url | bash` command
# and want to prevent partial execution of the script.

__installer__fn__setup() {
  vENTRY_DIR="${PWD}"
  trap 'cd '"${vENTRY_DIR}"'' EXIT

  vBIN_PATH="${HOME}/.solos/src/host/bridge.sh"
  vUSR_BIN_PATH="/usr/local/bin/solos"
  vGITHUB_REPO_URL="https://github.com/InterBolt/solos.git"
  vTMP_DIR="$(mktemp -d 2>/dev/null)"
  vSOLOS_HOME_DIR="${HOME}/.solos"

  if [[ -z ${vTMP_DIR} ]]; then
    echo "Failed to create temporary directory." >&2
    return 1
  fi
}

__installer__fn__clone() {
  if ! git clone "${vGITHUB_REPO_URL}" "${vTMP_DIR}/src" >/dev/null 2>&1; then
    echo "Failed to clone ${vGITHUB_REPO_URL} to ${vTMP_DIR}/src" >&2
    exit 1
  fi
}
__installer__fn__init_fs() {
  local solos_bashrc="${vSOLOS_HOME_DIR}/.bashrc"
  local src_dir="${vSOLOS_HOME_DIR}/src"

  mkdir -p "${vSOLOS_HOME_DIR}" || exit 1

  if [[ ! -f "${solos_bashrc}" ]]; then
    cat <<EOF >"${solos_bashrc}"
#!/usr/bin/env bash

. "\${HOME}/.solos/src/container/profile-bashrc.sh" "\$@"

# Add your customizations to the SolOS shell.
# Tip: type \`info\` in the shell to see what functions and aliases are available.

# WARNING: Define any custom functions or alias ABOVE the call to \`install_solos\`
# unless you really know what you're doing.
# Enable SolOS:
install_solos
EOF
  fi
  if [[ "${src_dir}" != "${HOME}/"*"/"* ]]; then
    echo "The source directory must be a subchild of your \$HOME directory." >&2
    exit 1
  else
    rm -rf "${src_dir}" || exit 1
    mkdir -p "${src_dir}" || exit 1
    cp -r "${vTMP_DIR}/src/." "${src_dir}" || exit 1
  fi
}
__installer__fn__symlink() {
  if ! ln -sfv "${vBIN_PATH}" "${vUSR_BIN_PATH}" >/dev/null; then
    echo "Failed to link ${vBIN_PATH} to ${vUSR_BIN_PATH}" >&2
    exit 1
  fi
  if ! chmod +x "${vUSR_BIN_PATH}"; then
    echo "Failed to make ${vUSR_BIN_PATH} executable." >&2
    exit 1
  fi
}
__installer__fn__install() {
  if ! __installer__fn__clone; then
    echo "SolOS installation failed." >&2
    echo "Failed to clone SolOS repository." >&2
    return 1
  fi
  if ! __installer__fn__init_fs; then
    echo "SolOS installation failed." >&2
    echo "Failed to initialize SolOS filesystem." >&2
    return 1
  fi
  if ! __installer__fn__symlink; then
    echo "SolOS installation failed." >&2
    echo "Failed to link SolOS executable to /usr/local/bin/solos." >&2
    return 1
  fi
  if ! "${vUSR_BIN_PATH}" --installer-no-tty --restricted-noop; then
    echo "SolOS installation failed." >&2
    echo "Failed to run SolOS cli after installing it." >&2
    return 1
  fi
  echo "Run \`solos --help\` to view CLI instructions."
}

__installer__fn__main() {
  if ! __installer__fn__setup; then
    exit 1
  fi
  if ! __installer__fn__install; then
    exit 1
  fi
}

__installer__fn__main
