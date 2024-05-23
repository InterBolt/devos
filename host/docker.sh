#!/usr/bin/env bash

__docker__var__rag_dir="${HOME}/.solos/rag"
__docker__var__rag_captured="${__docker__var__rag_dir}/captured"
__docker__var__repo_launch_dir="${HOME}/.solos/src/launchfiles"
__docker__var__bin_path="$(readlink -f "$0" || echo "${HOME}/.solos/src/cli/solos.sh")"
if [[ -z ${__docker__var__bin_path} ]]; then
  echo "Unexpected error: couldn't detect symbolic linking" >&2
  exit 1
fi
__docker__var__bin_dir="$(dirname "${__docker__var__bin_path}")"
__docker__var__volume_config_hostfile="${HOME}/.solos/store/users_home_dir"
__docker__var__volume_mounted="/root/.solos"
__docker__var__installer_no_tty_flag=false
__docker__var__next_args=()
for entry_arg in "$@"; do
  if [[ ${entry_arg} = "--installer-no-tty" ]]; then
    __docker__var__installer_no_tty_flag=true
  else
    __docker__var__next_args+=("${entry_arg}")
  fi
done
set -- "${__docker__var__next_args[@]}" || exit 1

. "${HOME}/.solos/src/pkgs/gum.sh"

__docker__fn__hash() {
  git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
__docker__fn__destroy() {
  for image_name in $(docker ps -a --format '{{.Image}}'); do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
    fi
  done
}
__docker__fn__symlinks() {
  __docker__fn__exec_command rm -rf /usr/local/bin/*_solos
  for solos_bin_file in "${HOME}/.solos/src/path-commands"/*; do
    local container_usr_bin_local_file="${solos_bin_file/#$HOME//root}"
    if [[ -f ${solos_bin_file} ]]; then
      chmod +x "${solos_bin_file}"
      __docker__fn__exec_command ln -sf \
        "${container_usr_bin_local_file}" \
        "/usr/local/bin/$(basename "${container_usr_bin_local_file}" | cut -d'.' -f1)_solos"
    fi
  done
}
__docker__fn__reset_bpftrace_scripts() {
  local ebpf_dir=".solos/src/ebpf"
  if [[ ! -d ${HOME}/${ebpf_dir} ]]; then
    echo "The ebpf directory at ${HOME}/${ebpf_dir} does not exist." >&2
    return 1
  fi
  __docker__fn__exec_command jobs -l | grep 'nohup bpftrace /root/'"${ebpf_dir}"'' | tr -s ' ' | cut -d' ' -f2 | xargs kill -9 2>/dev/null
  for bpf_file in "${HOME}/${ebpf_dir}"/*.bf; do
    local container_bpf_file="${bpf_file/#$HOME//root}"
    if [[ -f ${bpf_file} ]]; then
      local outfile="${container_bpf_file/%.bf/.out}"
      local outfilename=".nohup.$(basename "${outfile}")"
      __docker__fn__exec_command '(nohup bpftrace "'"${container_bpf_file}"'" >"'"/root/${ebpf_dir}/${outfilename}"'" 2>&1 &)'
    fi
  done
}
__docker__fn__test() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__docker__fn__hash)" echo "")
  else
    args=(-it -w "${container_ctx}" "$(__docker__fn__hash)" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
__docker__fn__exec_shell() {
  local bashrc_file="${1:-""}"
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__docker__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__docker__fn__hash)")
  fi
  local bash_args=()
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "The supplied bashrc file at ${bashrc_file} does not exist." >&2
      sleep 10
      exit 1
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    bash_args=(--rcfile "${relative_bashrc_file}")
  fi

  local entry_dir="${PWD}"
  cd "${HOME}/.solos/src" || exit 1
  ./profile/relay-cmd-server.sh || exit 1
  cd "${entry_dir}" || exit 1
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}" -i
}
__docker__fn__exec_command() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  local bash_args=()
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__docker__fn__hash)")
    bash_args=(-c ''"${*}"'')
  else
    args=(-it -w "${container_ctx}" "$(__docker__fn__hash)")
    bash_args=(-i -c ''"${*}"'')
  fi
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
__docker__fn__build_and_run() {
  if [[ -f ${HOME}/.solos ]]; then
    echo "Unhandled: a file called .solos was detected in your home directory." >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__docker__var__volume_config_hostfile}")"
  echo "${HOME}" >"${__docker__var__volume_config_hostfile}"
  if ! docker build -t "solos:$(__docker__fn__hash)" -f "${__docker__var__repo_launch_dir}/Dockerfile.shell" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    read -r -p "Press enter to exit..."
    exit 1
  fi
  if ! docker volume create --driver local --opt type=debugfs --opt device=debugfs debugfs; then
    echo "Unexpected error: failed to create the debugfs volume." >&2
    read -r -p "Press enter to exit..."
    exit 1
  fi
  local shared_docker_run_args=(
    --name
    "$(__docker__fn__hash)"
    -d
    --network
    host
    --pid
    host
    --privileged
    -v
    /usr/src:/usr/src:ro
    -v
    /lib/modules:/lib/modules:ro
    -v
    debugfs:/sys/kernel/debug:rw
    -v
    /sys/kernel/btf/vmlinux:/sys/kernel/btf/vmlinux:ro
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${HOME}/.solos:${__docker__var__volume_mounted}"
    "solos:$(__docker__fn__hash)"
  )
  if [[ ${__docker__var__installer_no_tty_flag} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! __docker__fn__test; do
    sleep .2
  done
}
__docker__fn__shell() {
  if __docker__fn__test; then
    __docker__fn__symlinks
    # __docker__fn__reset_bpftrace_scripts
    __docker__fn__exec_shell "$@"
    return 0
  fi
  if ! __docker__fn__destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    exit 1
  fi
  __docker__fn__build_and_run
  __docker__fn__symlinks
  # __docker__fn__reset_bpftrace_scripts
  __docker__fn__exec_shell "$@"
}
__docker__fn__run() {
  if __docker__fn__test; then
    __docker__fn__symlinks
    # __docker__fn__reset_bpftrace_scripts
    __docker__fn__exec_command "$@"
    return 0
  fi
  if ! __docker__fn__destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    exit 1
  fi
  __docker__fn__build_and_run
  __docker__fn__symlinks
  # __docker__fn__reset_bpftrace_scripts
  __docker__fn__exec_command "$@"
}
