#!/usr/bin/env bash

shopt -s extdebug

. "${HOME}/.solos/src/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1
. "${HOME}/.solos/src/profile/rag.sh" || exit 1
. "${HOME}/.solos/src/profile/bash-preexec.sh" || exit 1

if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
fi

__bashrc__fn__bash_completions() {
  _custom_command_completions() {
    local cur prev words cword
    _init_completion || return
    _command_offset 1
  }
  complete -F _custom_command_completions rag
  complete -F _custom_command_completions host
}

__bashrc__fn__host() {
  local done_file="${HOME}/.solos/relay/done"
  local command_file="${HOME}/.solos/relay/command"
  local stdout_file="${HOME}/.solos/relay/stdout"
  local stderr_file="${HOME}/.solos/relay/stderr"
  local cmd=''"${*}"''
  rm -f "${stdout_file}"
  echo "" >"${done_file}"
  echo "" >"${stderr_file}"
  echo "" >"${stdout_file}"
  echo ''"${cmd}"'' >"${command_file}"
  while [[ $(cat "${done_file}") != "DONE" ]]; do
    sleep 0.1
  done
  stdout="$(cat "${stdout_file}")"
  stderr="$(cat "${stderr_file}")"
  rm -f "${done_file}" "${command_file}" "${stdout_file}" "${stderr_file}"
  if [[ -n ${stdout} ]]; then
    echo "${stdout}"
  fi
  if [[ -n ${stderr} ]]; then
    echo "${stderr}" >&2
  fi
}

__bashrc__fn__print_commands() {
  cat <<EOF
- man:                        Print info about this shell.
- rag \$@:                     Take notes and capture stdout lines starting with \`[RAG]*\`. See \`rag --help\`.
- log_<level> \$@:             Log a message. Try: \`log_info "Hello, world!"\`.
- host \$@:                    Evaluates args as a command on the host machine. Try: \`host --help\`.
- solos \$@:                   A CLI utility for managing deployment servers. See \`solos --help\`.
- dsolos \$@:                  A restricted version of \`solos\` for developers. See \`dsolos --help\`.
- gh_token:                   Update the Github token.
- gh_email:                   Update the Github email.
- gh_name:                    Update the Github username.
EOF
}

__bashrc__fn__print_about_shell() {
  cat <<EOF
- Shell:                       BASH
- Working Dir:                 ${PWD}
- Home Dir:                    ${HOME}
- Bash Version:                ${BASH_VERSION}
- OS Distro:                   $(lsb_release -d | cut -f2)
EOF
}

__bashrc__fn__print_customizations() {
  cat <<EOF
- User managed rcfile:        ~/.solos/.bashrc
- Internal rcfile:            ~/.solos/src/profile/bashrc.sh
- Secrets:                    ~/.solos/secrets
- Logs:                       ~/.solos/logs
- Captured notes and stdout:  ~/.solos/rag
- Host <=> Container relay:   ~/.solos/relay
- Store:                      ~/.solos/store
- SolOS's source code:        ~/.solos/src
EOF
}

__bashrc__fn__print_man() {
  cat <<EOF
Commands:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
$(__bashrc__fn__print_commands)

Relevant paths:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
$(__bashrc__fn__print_customizations)

About containerized shell:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
$(__bashrc__fn__print_about_shell)

Source code:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
https://github.com/interbolt/solos
EOF
}

__bashrc__fn__print_welcome_manual() {
  cat <<EOF

Welcome to the SolOS Shell!

$(__bashrc__fn__print_man)

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo -e "\033[0;32mLogged in to Github ${gh_status_line} \033[0m"
  echo ""
}

__bashrc__fn__ide_shell() {
  PS1='\[\033[0;32m\](SolOS:Debian)\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '
  local warnings=()
  mkdir -p "${HOME}/.solos/secrets"
  local gh_token_path="${HOME}/.solos/secrets/gh_token"
  if [[ ! -f ${gh_token_path} ]]; then
    gum_github_token >"${gh_token_path}"
  fi
  local gh_cmd_available=false
  if command -v gh >/dev/null 2>&1; then
    gh_cmd_available=true
  fi
  if [[ ${gh_cmd_available} = false ]]; then
    warnings+=("The 'gh' command is not available. This shell is not authenticated with Git.")
  elif [[ ! -f ${gh_token_path} ]]; then
    warnings+=("The 'gh' command is available but no token was found at ${gh_token_path}.")
  elif ! gh auth login --with-token <"${gh_token_path}" >/dev/null; then
    warnings+=("Failed to authenticate with Git.")
  elif ! gh auth setup-git 2>/dev/null; then
    warnings+=("Failed to setup Git.")
  fi
  if [[ -f "/etc/bash_completion" ]]; then
    . /etc/bash_completion
  else
    warnings+=("/etc/bash_completion not found. Bash completions will not be available.")
  fi
  local gh_email="$(__bashrc__fn__host git config --global user.email)"
  local gh_user="$(__bashrc__fn__host git config --global user.name)"
  if [[ -n ${gh_email} ]]; then
    git config --global user.email "${gh_email}"
  else
    warnings+=("No email found in Git configuration.")
  fi
  if [[ -n ${gh_user} ]]; then
    git config --global user.name "${gh_user}"
  else
    warnings+=("No username found in Git configuration.")
  fi
  if [[ ${warnings} ]]; then
    for warning in "${warnings[@]}"; do
      echo -e "\033[0;31mWARNING:\033[0m ${warning}"
      sleep .2
    done
  fi
  __bashrc__fn__print_welcome_manual
  # Bash completions and custom completions for prefix commands like "rag".
  __bashrc__fn__bash_completions
}

__bashrc__fn__preeexec_app_context() {
  local entry_pwd="${PWD}"
  local first_arg="$1"
  if [[ -f ${first_arg} ]]; then
    cd "$(dirname "${first_arg}")" || exit 1
    first_arg="$(basename "${first_arg}")"
  fi
  if [[ ${PWD} =~ ^${HOME}/\.solos/projects/([^/]*)/apps/([^/]*) ]]; then
    local project_name="${BASH_REMATCH[1]}"
    local app_name="${BASH_REMATCH[2]}"
    local preexec_script="${HOME}/.solos/projects/${project_name}/apps/${app_name}/solos.preexec.sh"
    if [[ -f ${preexec_script} ]]; then
      "${preexec_script}"
    fi
  fi
  cd "${entry_pwd}" || exit 1
  return 0
}

__bashrc__fn__preexec_shell() {
  local cmd="${*}"
  if [[ ${cmd} = "exit" ]]; then
    return 0
  fi
  if [[ ${cmd} = "host "* ]]; then
    return 0
  fi
  if [[ ${cmd} = "cd "* ]]; then
    return 0
  fi
  if [[ ${cmd} = "cd" ]]; then
    return 0
  fi
  if [[ ${cmd} = "rag captured" ]]; then
    local line_count="$(wc -l <"${HOME}/.solos/rag/captured")"
    code -g "${HOME}/.solos/rag/captured:${line_count}"
    return 1
  fi
  if [[ ${cmd} = "rag notes" ]]; then
    local line_count="$(wc -l <"${HOME}/.solos/rag/notes")"
    code -g "${HOME}/.solos/rag/notes:${line_count}"
    return 1
  fi
  if [[ ${cmd} = "code "* ]]; then
    return 0
  fi
  if [[ ${cmd} = "rag "* ]]; then
    return 0
  fi
  rag --captured-only ''"${cmd}"''
  return 1
}

__bashrc__fn__main() {
  # Handle the case where this rcfile is sourced from an app context.
  while [[ $# -gt 0 ]]; do
    if [[ ${1} = "--with-app-context" ]]; then
      preexec_functions+=("__bashrc__fn__preeexec_app_context")
      exit 0
    fi
  done
  # Do a bunch of setup stuff
  __bashrc__fn__ide_shell
  # Add preeval logic which will ensure that the stdout lines starting with [RAG] are captured.
  # A few things like cd, exit, and host commands are ignored.
  preexec_functions+=("__bashrc__fn__preexec_shell")
}

__bashrc__fn__main "$@"

# Public stuff
rag() {
  __rag__fn__main "$@"
}
host() {
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
Usage: host ...<any command here>...

Description:

Any command that you run with 'host' prefix will be executed on the host machine.

Limitations:

- Commands that

Example:

If your host machine is not running Debian, try running 'host uname' to see the output of the 'uname' command on your host machine.

How it works:

It doesn't use unix pipes. Rather, the SolOS shell starts a background process upon launch which periodically checks a txt file for a
new command from the docker container. Once a command is found it is executed on the host machine and the output is written
to a couple different txt files within the mounted volume. The SolOS shell then reads the output from the txt file and prints
it as if it were the output of the command that was run.
EOF
    return 0
  fi
  __bashrc__fn__host "$@"
}
gh_token() {
  local tmp_file="$(mktemp -q)"
  local gh_token_path="${HOME}/.solos/secrets/gh_token"
  gum_github_token >"${tmp_file}" || exit 1
  gh_token=$(cat "${tmp_file}")
  if gh auth login --with-token <"${tmp_file}" >/dev/null; then
    log_info "Updated Github token."
    # Wait for a successful login before saving it.
    echo "${gh_token}" >"${gh_token_path}"
    gh auth status
  fi
}
gh_email() {
  local tmp_file="$(mktemp -q)"
  gum_github_email >"${tmp_file}" || exit 1
  local gh_email=$(cat "${tmp_file}")
  git config --global user.email "${gh_email}"
  host git config --global user.email "${gh_email}"
}
gh_name() {
  local tmp_file="$(mktemp -q)"
  gum_github_name >"${tmp_file}" || exit 1
  local gh_name=$(cat "${tmp_file}")
  git config --global user.name "${gh_name}"
  host git config --global user.name "${gh_name}"
}
code() {
  local bin_path="$(__bashrc__fn__host which code)"
  host "${bin_path}" "${*}"
}
solos() {
  local executable_path="${HOME}/.solos/src/bin/solos.sh"
  bash "${executable_path}" "$@"
}
dsolos() {
  local executable_path="${HOME}/.solos/src/bin/solos.sh"
  bash "${executable_path}" --restricted-developer "$@"
}
man() {
  echo ""
  __bashrc__fn__print_man
  echo ""
}
