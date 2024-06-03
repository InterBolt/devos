#!/usr/bin/env bash

. "${HOME}"/.solos/src/host/cli-posthooks.sh || exit 1

bridge__data_dir="${HOME}/.solos/data"
bridge__repo_dir="${HOME}/.solos/src"
bridge__users_home_dir="${HOME}/.solos/data/store/users_home_dir"
bridge__mount_dir="/root/.solos"
bridge__installer_no_tty_flag=false
bridge__shell_minimal_flag=false
bridge__shell_full_flag=false
bridge__cli_flag=true
bridge__next_args=()

# Map the flags to the relevant values and remove them from the args.
for entry_arg in "$@"; do
  if [[ ${entry_arg} = "--installer-no-tty" ]]; then
    bridge__installer_no_tty_flag=true
  elif [[ ${entry_arg} = "shell-minimal" ]]; then
    bridge__shell_minimal_flag=true
    bridge__shell_full_flag=false
    bridge__cli_flag=false
  elif [[ ${entry_arg} = "shell" ]]; then
    bridge__shell_full_flag=true
    bridge__shell_minimal_flag=false
    bridge__cli_flag=false
  elif [[ ${entry_arg} = "--cli" ]]; then
    bridge__cli_flag=true
  else
    bridge__next_args+=("${entry_arg}")
  fi
done
set -- "${bridge__next_args[@]}" || exit 1

export DOCKER_CLI_HINTS=false

bridge.error_press_enter() {
  echo "Press enter to exit..."
  read -r || exit 1
  exit 1
}
bridge.hash() {
  git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
bridge.destroy() {
  for image_name in $(docker ps -a --format '{{.Image}}'); do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
    fi
  done
}
bridge.test() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(bridge.hash)" echo "")
  else
    args=(-it -w "${container_ctx}" "$(bridge.hash)" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
bridge.launch_daemon() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=(-i -w "${container_ctx}" "$(bridge.hash)")
  local bash_args=(-c 'nohup /root/.solos/src/container/daemon.sh >/dev/null 2>&1 &')
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
bridge.exec_shell() {
  local bashrc_file="${1:-""}"
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(bridge.hash)")
  else
    args=(-it -w "${container_ctx}" "$(bridge.hash)")
  fi
  local bash_args=()
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "The supplied bashrc file at ${bashrc_file} does not exist." >&2
      bridge.error_press_enter
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    bash_args=(--rcfile "${relative_bashrc_file}")
  fi

  docker exec "${args[@]}" /bin/bash "${bash_args[@]}" -i
}
bridge.exec_command() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  local bash_args=()
  if [[ ${bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(bridge.hash)")
    bash_args=(-c ''"${*}"'')
  else
    args=(-it -w "${container_ctx}" "$(bridge.hash)")
    bash_args=(-i -c ''"${*}"'')
  fi
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
bridge.build_and_run() {
  if [[ -f ${HOME}/.solos ]]; then
    echo "Unhandled: a file called .solos was detected in your home directory." >&2
    exit 1
  fi
  mkdir -p "$(dirname "${bridge__users_home_dir}")"
  echo "${HOME}" >"${bridge__users_home_dir}"
  if ! docker build -t "solos:$(bridge.hash)" -f "${bridge__repo_dir}/Dockerfile" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    bridge.error_press_enter
  fi
  local shared_docker_run_args=(
    --name
    "$(bridge.hash)"
    -d
    --network
    host
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${HOME}/.solos:${bridge__mount_dir}"
    "solos:$(bridge.hash)"
  )
  if [[ ${bridge__installer_no_tty_flag} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! bridge.test; do
    sleep .2
  done
  bridge.launch_daemon
}
bridge.rebuild() {
  if ! bridge.destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    bridge.error_press_enter
  fi
  if ! bridge.build_and_run; then
    echo "Unexpected error: failed to build and run the container." >&2
    bridge.error_press_enter
  fi
}
bridge.shell() {
  if bridge.test; then
    bridge.exec_shell "$@"
    return 0
  fi
  bridge.rebuild
  bridge.exec_shell "$@"
}
bridge.cmd() {
  if bridge.test; then
    bridge.exec_command "$@"
    return 0
  fi
  bridge.rebuild
  bridge.exec_command "$@"
}
bridge.exec_cli() {
  local post_behavior="$(cli_posthooks.determine_command "$@")"
  if bridge.cmd /root/.solos/src/container/cli.sh "$@"; then
    if [[ -n ${post_behavior} ]]; then
      if [[ "$*" == *" --help"* ]] || [[ "$*" == *" help"* ]]; then
        return 0
      fi
      # The first arg is the command.
      shift
      "cli_posthooks.${post_behavior}" "$@"
    fi
  fi
}
bridge.cli() {
  local curr_project="$(
    head -n 1 "${HOME}"/.solos/data/store/checked_out_project 2>/dev/null || echo ""
  )"
  local solos_cmd=""
  local args=("$@")
  for arg in "${args[@]}"; do
    if [[ ${arg} != --* ]]; then
      solos_cmd="${arg}"
    fi
  done
  if [[ -z ${solos_cmd} ]] || [[ ${solos_cmd} = "checkout" ]]; then
    bridge.destroy
  fi
  bridge.exec_cli "${args[@]}"
}
bridge.main() {
  mkdir -p "${bridge__data_dir}"
  if [[ ${bridge__cli_flag} = true ]]; then
    local cli_args=()
    for entry_arg in "$@"; do
      if [[ ${entry_arg} != shell ]] && [[ ${entry_arg} != shell-* ]]; then
        cli_args+=("${entry_arg}")
      fi
    done
    bridge.cli "${cli_args[@]}"
    exit $?
  elif [[ ${bridge__shell_minimal_flag} = true ]]; then
    bridge.shell
    exit $?
  elif [[ ${bridge__shell_full_flag} = true ]]; then
    bridge.shell "${HOME}/.solos/rcfiles/.bashrc"
    exit $?
  else
    echo "Unexpected error: invalid, incorrect, or missing flags." >&2
    exit 1
  fi
}

bridge.main "$@"
