#!/usr/bin/env bash

ENTRY_DIR="${PWD}"
trap 'cd '"${ENTRY_DIR}"'' EXIT

BIN_PATH="/usr/local/bin/solos"
SOLOS_HOME_DIR="${HOME}/.solos"
PREV_RETURN=()

fn_clone() {
  local tmp_source_root="$(mktemp -d 2>/dev/null)/src"
  local repo_url="https://github.com/InterBolt/solos.git"
  if ! git clone "${repo_url}" "${tmp_source_root}" >/dev/null 2>&1; then
    echo "Failed to clone ${repo_url} to ${tmp_source_root}" >&2
    exit 1
  fi
  if [[ ! -f "${tmp_source_root}/host/bin.sh" ]]; then
    echo "${tmp_source_root}/host/bin.sh not found." >&2
    exit 1
  fi
  PREV_RETURN=("${tmp_source_root}")
}
fn_init_fs() {
  local tmp_src_dir="${1}"
  local SOLOS_HOME_DIR="${HOME}/.solos"
  local solos_bashrc="${SOLOS_HOME_DIR}/.bashrc"
  local src_dir="${SOLOS_HOME_DIR}/src"

  mkdir -p "${SOLOS_HOME_DIR}" || exit 1

  if [[ ! -f "${solos_bashrc}" ]]; then
    cat <<EOF >"${solos_bashrc}"
#!/usr/bin/env bash

. "\${HOME}/.solos/src/container/profile-bashrc.sh" "\$@"

# Add your customizations to the SolOS shell.
# Tip: type \`man\` in the shell to see what functions and aliases are available.

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
    cp -r "${tmp_src_dir}/." "${src_dir}" || exit 1
  fi
}
fn_link_bin() {
  local src_bin_path="${HOME}/.solos/src/host/bin.sh"
  local BIN_PATH="/usr/local/bin/solos"
  if ! ln -sfv "${src_bin_path}" "${BIN_PATH}" >/dev/null; then
    echo "Failed to link ${src_bin_path} to ${BIN_PATH}" >&2
    exit 1
  fi
  if ! chmod +x "${BIN_PATH}"; then
    echo "Failed to make ${BIN_PATH} executable." >&2
    exit 1
  fi
}
fn_main() {
  local BIN_PATH="/usr/local/bin/solos"
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to install SolOS on this system." >&2
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "Git is required to install SolOS on this system." >&2
    return 1
  fi
  if ! fn_clone; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  if ! fn_init_fs "${PREV_RETURN[0]}"; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  if ! fn_link_bin; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  if ! "${BIN_PATH}" --installer-no-tty --restricted-noop; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  echo "Run \`solos --help\` to get started."
}

if ! fn_main; then
  exit 1
fi
