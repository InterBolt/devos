#!/usr/bin/env bash

installer.setup() {

  local installer__flag_is_dev=false
  if [[ "${1}" = "--dev" ]]; then
    installer__flag_is_dev=true
  fi
  installer__entry_dir="${PWD}"
  trap 'cd '"${installer__entry_dir}"'' EXIT

  installer__bin_path="${HOME}/.solos/src/host/bin.sh"
  installer__usr_bin_path="/usr/local/bin/solos"
  installer__github_repo="https://github.com/InterBolt/solos.git"
  installer__tmp_dir="$(mktemp -d 2>/dev/null)"
  installer__solos_home_dir="${HOME}/.solos"
  installer__setup_demo_script="${installer__solos_home_dir}/src/scripts/setup-demo.sh"

  if [[ -z ${installer__tmp_dir} ]]; then
    echo "Failed to create temporary directory." >&2
    return 1
  fi
}

installer.clone() {
  if ! git clone "${installer__github_repo}" "${installer__tmp_dir}/src" >/dev/null 2>&1; then
    echo "Failed to clone ${installer__github_repo} to ${installer__tmp_dir}/src" >&2
    exit 1
  fi
}
installer.init_fs() {
  local solos_bashrc="${installer__solos_home_dir}/rcfiles/.bashrc"
  local solos_rcfiles_dir="$(dirname "${solos_bashrc}")"
  local src_dir="${installer__solos_home_dir}/src"

  mkdir -p "${installer__solos_home_dir}" || exit 1
  mkdir -p "${solos_rcfiles_dir}" || exit 1

  if [[ ! -f "${solos_bashrc}" ]]; then
    cat <<EOF >"${solos_bashrc}"
#!/usr/bin/env bash

. "\${HOME}/.solos/src/profiles/bash/bashrc.sh" "\$@"

# Add your customizations to the SolOS shell.
# Tip: type \`info\` in the shell to see what functions and aliases are available.

install_solos
EOF
  fi
  if [[ "${src_dir}" != "${HOME}/"*"/"* ]]; then
    echo "The source directory must be a subchild of your \$HOME directory." >&2
    exit 1
  else
    rm -rf "${src_dir}" || exit 1
    mkdir -p "${src_dir}" || exit 1
    cp -r "${installer__tmp_dir}/src/." "${src_dir}" || exit 1
  fi
}
installer.symlink() {
  if ! ln -sfv "${installer__bin_path}" "${installer__usr_bin_path}" >/dev/null; then
    echo "Failed to link ${installer__bin_path} to ${installer__usr_bin_path}" >&2
    exit 1
  fi
  if ! chmod +x "${installer__usr_bin_path}"; then
    echo "Failed to make ${installer__usr_bin_path} executable." >&2
    exit 1
  fi
}
installer.install() {
  if ! installer.clone; then
    echo "SolOS installation failed." >&2
    echo "Failed to clone SolOS repository." >&2
    return 1
  fi
  if ! installer.init_fs; then
    echo "SolOS installation failed." >&2
    echo "Failed to initialize SolOS filesystem." >&2
    return 1
  fi
  if ! installer.symlink; then
    echo "SolOS installation failed." >&2
    echo "Failed to link SolOS executable to /usr/local/bin/solos." >&2
    return 1
  fi
  if [[ ${installer__flag_is_dev} = true ]]; then
    echo "DEV MODE ENABLED" >&2
    if ! bash -ic "${installer__setup_demo_script}"; then
      echo "SolOS installation failed." >&2
      echo "Failed to run SolOS setup-demo script." >&2
      return 1
    fi
  fi
  if ! "${installer__usr_bin_path}" --installer-no-tty --restricted-noop; then
    echo "SolOS installation failed." >&2
    echo "Failed to run SolOS cli after installing it." >&2
    return 1
  fi
  bash -ic "solos setup"
}

installer.main() {
  if ! installer.setup "$@"; then
    exit 1
  fi
  if ! installer.install "$@"; then
    exit 1
  fi
  echo "${installer__solos_home_dir}"
}

installer.main "$@"
