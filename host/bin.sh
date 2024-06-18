#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}"/.solos/src/host/cli-posthooks.sh || exit 1

bin__data_dir="$(lib.data_dir_path)"
bin__repo_dir="${HOME}/.solos/src"
bin__store_dir="${HOME}/.solos/data/store"
bin__stored_users_home_dir="${bin__store_dir}/users_home_dir"
bin__last_docker_build_hash="$(lib.last_docker_build_hash_path)"
bin__mount_dir="/root/.solos"
bin__mounted_daemon_path="/root/.solos/src/daemon/bin.sh"
bin__mounted_cli_path="/root/.solos/src/cli/bin.sh"
bin__users_bashrc_path="${HOME}/.solos/rcfiles/.bashrc"
bin__installer_no_tty_flag=false
bin__shell_minimal_flag=false
bin__shell_full_flag=false
bin__cli_flag=true
bin__next_args=()

# Map the flags to the relevant values and remove them from the args.
for entry_arg in "$@"; do
  if [[ ${entry_arg} = "--installer-no-tty" ]]; then
    bin__installer_no_tty_flag=true
  elif [[ ${entry_arg} = "shell-minimal" ]]; then
    bin__shell_minimal_flag=true
    bin__shell_full_flag=false
    bin__cli_flag=false
  elif [[ ${entry_arg} = "shell" ]]; then
    bin__shell_full_flag=true
    bin__shell_minimal_flag=false
    bin__cli_flag=false
  else
    bin__next_args+=("${entry_arg}")
  fi
done
set -- "${bin__next_args[@]}" || exit 1

export DOCKER_CLI_HINTS=false

bin.error_press_enter() {
  echo "Press enter to exit..."
  read -r || exit 1
  exit 1
}
bin.hash() {
  git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
bin.destroy() {
  for image_name in $(docker ps -a --format '{{.Image}}'); do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
    fi
  done
}
bin.test() {
  local hash="${1}"
  local args=()
  if [[ ${bin__installer_no_tty_flag} = true ]]; then
    args=(-i -w "/root/.solos/src" "${hash}" echo 'CONTAINER READY')
  else
    args=(-it -w "/root/.solos/src" "${hash}" echo 'CONTAINER READY')
  fi
  if ! docker exec "${args[@]}" 2>/dev/null; then
    return 1
  fi
  return 0
}
bin.launch_daemon() {
  local hash="${1}"
  local args=(-i -w "/root/.solos/src" "${hash}")
  local bash_args=(-c 'nohup '"${bin__mounted_daemon_path}"' >/dev/null 2>&1 &')
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
bin.exec_shell() {
  local hash="${1}"
  local bashrc_file="${2:-""}"
  local args=()
  if [[ ${bin__installer_no_tty_flag} = true ]]; then
    args=(-i -w "/root/.solos/src" "${hash}")
  else
    args=(-it -w "/root/.solos/src" "${hash}")
  fi
  local bash_args=()
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "The supplied bashrc file at ${bashrc_file} does not exist." >&2
      bin.error_press_enter
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    bash_args=(--rcfile "${relative_bashrc_file}")
  fi

  docker exec "${args[@]}" /bin/bash "${bash_args[@]}" -i
}
bin.exec_command() {
  local hash="${1}"
  local args=()
  local bash_args=()
  if [[ ${bin__installer_no_tty_flag} = true ]]; then
    args=(-i -w "/root/.solos/src" "${hash}")
    bash_args=(-c ''"${*}"'')
  else
    args=(-it -w "/root/.solos/src" "${hash}")
    bash_args=(-i -c ''"${*}"'')
  fi
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
bin.build_and_run() {
  if [[ -f ${HOME}/.solos ]]; then
    echo "A file called .solos was detected in your home directory." >&2
    bin.error_press_enter
  fi
  mkdir -p "$(dirname "${bin__stored_users_home_dir}")"
  echo "${HOME}" >"${bin__stored_users_home_dir}"
  local prev_hash="$(cat "${bin__last_docker_build_hash}" 2>/dev/null || echo "")"
  local hash="$(bin.hash)"
  local build_args=(-q)
  if [[ ${prev_hash} != "${hash}" ]]; then
    build_args=()
  fi
  if ! docker build "${build_args[@]}" -t "solos:${hash}" -f "${bin__repo_dir}/Dockerfile" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    bin.error_press_enter
  fi
  echo "${hash}" >"${bin__last_docker_build_hash}"
  local shared_docker_run_args=(
    --name
    "${hash}"
    -d
    --network
    host
    --pid
    host
    --privileged
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${HOME}/.solos:${bin__mount_dir}"
    "solos:${hash}"
  )
  if [[ ${bin__installer_no_tty_flag} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}"
  else
    docker run -it "${shared_docker_run_args[@]}"
  fi
  while ! bin.test "${hash}"; do
    sleep .2
  done
  bin.launch_daemon "${hash}"
}
bin.rebuild() {
  echo -e "\033[0;34mRebuilding the container...\033[0m"
  if ! bin.destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    bin.error_press_enter
  fi
  if ! bin.build_and_run; then
    echo "Unexpected error: failed to build and run the container." >&2
    bin.error_press_enter
  fi
}
bin.shell() {
  local hash="$(bin.hash)"
  if bin.test "${hash}"; then
    bin.exec_shell "${hash}" "$@"
    return 0
  fi
  bin.rebuild
  bin.exec_shell "${hash}" "$@"
}
bin.cmd() {
  local hash="$(bin.hash)"
  if bin.test "${hash}"; then
    bin.exec_command "${hash}" "$@"
    return 0
  fi
  bin.rebuild
  bin.exec_command "${hash}" "$@"
}
bin.cli() {
  local curr_project="$(lib.checked_out_project)"
  local solos_cmd=""
  local args=("$@")
  for arg in "${args[@]}"; do
    if [[ ${arg} != "--"* ]]; then
      solos_cmd="${arg}"
    fi
  done
  echo "HY MAN"
  if [[ -z ${solos_cmd} ]] || [[ ${solos_cmd} = "checkout" ]]; then
    bin.destroy
  fi
  echo "HY MAN 2"
  local post_behavior="$(cli_posthooks.determine_command "${args[@]}")"
  if bin.cmd "${bin__mounted_cli_path}" "${args[@]}"; then
    if [[ -n ${post_behavior} ]]; then
      if [[ "$*" = *" --help"* ]] || [[ "$*" = *" help"* ]]; then
        return 0
      fi
      # The first arg is the command.
      shift
      "cli_posthooks.${post_behavior}" "$@"
    fi
  fi
}
bin.main() {
  mkdir -p "${bin__data_dir}"
  if [[ ${bin__cli_flag} = true ]]; then
    local cli_args=()
    for entry_arg in "$@"; do
      if [[ ${entry_arg} != "shell" ]] && [[ ${entry_arg} != "shell-"* ]]; then
        cli_args+=("${entry_arg}")
      fi
    done
    bin.cli "${cli_args[@]}"
    exit $?
  elif [[ ${bin__shell_minimal_flag} = true ]]; then
    bin.shell
    exit $?
  elif [[ ${bin__shell_full_flag} = true ]]; then
    bin.shell "${bin__users_bashrc_path}"
    exit $?
  else
    echo "Unexpected error: invalid, incorrect, or missing flags." >&2
    bin.error_press_enter
  fi
}

bin.main "$@"
