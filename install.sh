#!/usr/bin/env bash

__install__var__entry_dir="${PWD}"
trap 'cd '"${__install__var__entry_dir}"'' EXIT

__install__var__target_bin_path="/usr/local/bin/solos"
__install__var__bin_suffix=""
__install__var__cmd_prefix=""
if [[ $1 = "--dev" ]]; then
  __install__var__bin_suffix="-dev"
  __install__var__cmd_prefix="d"
  shift
fi
__install__var__solos_dir="${HOME}/.solos"
__install__var__solos_src_dir="${__install__var__solos_dir}/src"
__install__var__solos_vscode_bashrc_file="${__install__var__solos_dir}/.bashrc"
__install__var__prev_return=()

__install__fn__clone() {
  local tmp_source_root="$(mktemp -d 2>/dev/null)/src"
  local repo_url="https://github.com/InterBolt/solos.git"
  if ! git clone "${repo_url}" "${tmp_source_root}" >/dev/null 2>&1; then
    echo "Failed to clone ${repo_url} to ${tmp_source_root}" >&2
    exit 1
  fi
  if [[ ! -f "${tmp_source_root}/host/bin${__install__var__bin_suffix}.sh" ]]; then
    echo "${tmp_source_root}/host/bin${__install__var__bin_suffix}.sh not found." >&2
    exit 1
  fi
  __install__var__prev_return=("${tmp_source_root}")
}
__install__fn__init_fs() {
  local tmp_src_dir="${1}"
  local solos_dir="${HOME}/.solos"
  local solos_bashrc="${solos_dir}/.bashrc"
  local src_dir="${solos_dir}/src"

  mkdir -p "${solos_dir}" || exit 1

  if [[ ! -f "${solos_bashrc}" ]]; then
    cat <<EOF >"${solos_bashrc}"
#!/usr/bin/env bash

source "\${HOME}/.solos/src/profile/bashrc.sh"

# Add your customizations to the SolOS shell:
# Tip: type \`man\` in the shell to see what functions and aliases are available.
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
__install__fn__link_bin() {
  local src_bin_path="${HOME}/.solos/src/host/bin${__install__var__bin_suffix}.sh"
  local target_bin_path="/usr/local/bin/${__install__var__cmd_prefix}solos"
  if ! ln -sfv "${src_bin_path}" "${target_bin_path}" >/dev/null; then
    echo "Failed to link ${src_bin_path} to ${target_bin_path}" >&2
    exit 1
  fi
  if ! chmod +x "${target_bin_path}"; then
    echo "Failed to make ${target_bin_path} executable." >&2
    exit 1
  fi
}
__install__fn__main() {
  local target_bin_path="/usr/local/bin/${__install__var__cmd_prefix}solos"
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to install SolOS on this system." >&2
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "Git is required to install SolOS on this system." >&2
    return 1
  fi
  if ! __install__fn__clone; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  if ! __install__fn__init_fs "${__install__var__prev_return[0]}"; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  if ! __install__fn__link_bin; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  if ! "${target_bin_path}" --installer-no-tty --restricted-noop; then
    echo "SolOS installation failed." >&2
    return 1
  fi
  echo "Run \`${__install__var__cmd_prefix}solos --help\` to get started."
}

if ! __install__fn__main; then
  exit 1
fi
