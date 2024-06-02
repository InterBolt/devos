#!/usr/bin/env bash

. "${HOME}"/.solos/src/host/cli-posthooks.sh || exit 1

__bridge__collections_dir="${HOME}/.solos/collections"
__bridge__repo_dir="${HOME}/.solos/src"
__bridge__users_home_dir="${HOME}/.solos/store/users_home_dir"
__bridge__mount_dir="/root/.solos"
__bridge__installer_no_tty_flag=false
__bridge__shell_minimal_flag=false
__bridge__shell_full_flag=false
__bridge__cli_flag=true
__bridge__next_args=()

# Map the flags to the relevant values and remove them from the args.
for entry_arg in "$@"; do
  if [[ ${entry_arg} = "--installer-no-tty" ]]; then
    __bridge__installer_no_tty_flag=true
  elif [[ ${entry_arg} = "shell-minimal" ]]; then
    __bridge__shell_minimal_flag=true
    __bridge__shell_full_flag=false
    __bridge__cli_flag=false
  elif [[ ${entry_arg} = "shell" ]]; then
    __bridge__shell_full_flag=true
    __bridge__shell_minimal_flag=false
    __bridge__cli_flag=false
  elif [[ ${entry_arg} = "--cli" ]]; then
    __bridge__cli_flag=true
  else
    __bridge__next_args+=("${entry_arg}")
  fi
done
set -- "${__bridge__next_args[@]}" || exit 1

export DOCKER_CLI_HINTS=false

__bridge__fn__error_press_enter() {
  echo "Press enter to exit..."
  read -r || exit 1
  exit 1
}
__bridge__fn__hash() {
  git -C "${HOME}/.solos/src" rev-parse --short HEAD | cut -c1-7 || echo ""
}
__bridge__fn__destroy() {
  for image_name in $(docker ps -a --format '{{.Image}}'); do
    if [[ ${image_name} = "solos:"* ]]; then
      docker stop "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rm "$(docker ps -a --format '{{.ID}}' --filter ancestor="${image_name}")" >/dev/null 2>&1
      docker rmi "${image_name}" >/dev/null 2>&1
    fi
  done
}
__bridge__fn__test() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__bridge__fn__hash)" echo "")
  else
    args=(-it -w "${container_ctx}" "$(__bridge__fn__hash)" echo "")
  fi
  if ! docker exec "${args[@]}" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
__bridge__fn__exec_shell() {
  local bashrc_file="${1:-""}"
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__bridge__fn__hash)")
  else
    args=(-it -w "${container_ctx}" "$(__bridge__fn__hash)")
  fi
  local bash_args=()
  if [[ -n ${bashrc_file} ]]; then
    if [[ ! -f ${bashrc_file} ]]; then
      echo "The supplied bashrc file at ${bashrc_file} does not exist." >&2
      __bridge__fn__error_press_enter
    fi
    local relative_bashrc_file="${bashrc_file/#$HOME/~}"
    bash_args=(--rcfile "${relative_bashrc_file}")
  fi

  docker exec "${args[@]}" /bin/bash "${bash_args[@]}" -i
}
__bridge__fn__exec_command() {
  local container_ctx="${PWD/#$HOME//root}"
  local args=()
  local bash_args=()
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    args=(-i -w "${container_ctx}" "$(__bridge__fn__hash)")
    bash_args=(-c ''"${*}"'')
  else
    args=(-it -w "${container_ctx}" "$(__bridge__fn__hash)")
    bash_args=(-i -c ''"${*}"'')
  fi
  docker exec "${args[@]}" /bin/bash "${bash_args[@]}"
}
__bridge__fn__build_and_run() {
  if [[ -f ${HOME}/.solos ]]; then
    echo "Unhandled: a file called .solos was detected in your home directory." >&2
    exit 1
  fi
  mkdir -p "$(dirname "${__bridge__users_home_dir}")"
  echo "${HOME}" >"${__bridge__users_home_dir}"
  if ! docker build -t "solos:$(__bridge__fn__hash)" -f "${__bridge__repo_dir}/Dockerfile" .; then
    echo "Unexpected error: failed to build the docker image." >&2
    __bridge__fn__error_press_enter
  fi
  local shared_docker_run_args=(
    --name
    "$(__bridge__fn__hash)"
    -d
    --network
    host
    -v
    /var/run/docker.sock:/var/run/docker.sock
    -v
    "${HOME}/.solos:${__bridge__mount_dir}"
    "solos:$(__bridge__fn__hash)"
  )
  if [[ ${__bridge__installer_no_tty_flag} = true ]]; then
    docker run -i "${shared_docker_run_args[@]}" &
  else
    docker run -it "${shared_docker_run_args[@]}" &
  fi
  while ! __bridge__fn__test; do
    sleep .2
  done
}
__bridge__fn__rebuild() {
  if ! __bridge__fn__destroy; then
    echo "Unexpected error: failed to cleanup old containers." >&2
    __bridge__fn__error_press_enter
  fi
  if ! __bridge__fn__build_and_run; then
    echo "Unexpected error: failed to build and run the container." >&2
    __bridge__fn__error_press_enter
  fi
}
__bridge__fn__shell() {
  if __bridge__fn__test; then
    __bridge__fn__exec_shell "$@"
    return 0
  fi
  __bridge__fn__rebuild
  __bridge__fn__exec_shell "$@"
}
__bridge__fn__cmd() {
  if __bridge__fn__test; then
    __bridge__fn__exec_command "$@"
    return 0
  fi
  __bridge__fn__rebuild
  __bridge__fn__exec_command "$@"
}
__bridge__fn__exec_cli() {
  local post_behavior="$(__cli_posthooks__fn__determine_command "$@")"
  if __bridge__fn__cmd /root/.solos/src/container/cli.sh "$@"; then
    if [[ -n ${post_behavior} ]]; then
      if [[ "$*" == *" --help"* ]] || [[ "$*" == *" help"* ]]; then
        return 0
      fi
      # The first arg is the command.
      shift
      "__cli_posthooks__fn__${post_behavior}" "$@"
    fi
  fi
}
__bridge__fn__cli() {
  local curr_project="$(
    head -n 1 "${HOME}"/.solos/store/checked_out_project 2>/dev/null || echo ""
  )"
  local solos_cmd=""
  local args=("$@")
  for arg in "${args[@]}"; do
    if [[ ${arg} != --* ]]; then
      solos_cmd="${arg}"
    fi
  done
  if [[ -z ${solos_cmd} ]] || [[ ${solos_cmd} = "checkout" ]]; then
    __bridge__fn__destroy
  fi
  __bridge__fn__exec_cli "${args[@]}"
}
__bridge__fn__main() {
  if [[ ${__bridge__cli_flag} = true ]]; then
    local cli_args=()
    for entry_arg in "$@"; do
      if [[ ${entry_arg} != shell ]] && [[ ${entry_arg} != shell-* ]]; then
        cli_args+=("${entry_arg}")
      fi
    done
    __bridge__fn__cli "${cli_args[@]}"
    exit $?
  elif [[ ${__bridge__shell_minimal_flag} = true ]]; then
    __bridge__fn__shell
    exit $?
  elif [[ ${__bridge__shell_full_flag} = true ]]; then
    __bridge__fn__shell "${HOME}/.solos/rcfiles/.bashrc"
    exit $?
  else
    echo "Unexpected error: invalid, incorrect, or missing flags." >&2
    exit 1
  fi
}

__bridge__fn__main "$@"
