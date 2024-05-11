#!/usr/bin/env bash

shopt -s extdebug

__bashrc__var__self="${BASH_SOURCE[0]}"

__bashrc__fn__source_and_set_cwd() {
  local entry_pwd="${PWD}"
  cd "${HOME}/.solos/src/bin" || exit 1
  . pkg/__source__.sh || exit 1
  cd "${HOME}/.solos/src/bin" || exit 1
  . profile/rag.sh || exit 1
  cd "${HOME}/.solos/src/bin" || exit 1
  . external/bash-preexec.sh || exit 1
  cd "${HOME}/.solos/src/bin" || exit 1
  . profile/host.sh || exit 1
  cd "${entry_pwd}" || exit 1

  # The terminal should always start within the .solos directory.
  if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
    cd "${HOME}/.solos" || exit 1
  fi
}

__bashrc__fn__print_commands() {
  cat <<EOF
- \`man\`:                 Print info about the shell, available commands, and customization instructions.
- \`rag \$@\`:              Take notes and capture stdout lines starting with \`[RAG]*\`. See \`rag --help\`.
- \`solos \$@\`:            A CLI utility for managing deployment servers. See \`solos --help\`.
- \`dsolos \$@\`:           A restricted version of \`solos\` for developers. See \`dsolos --help\`.
- \`gh_update_token\`:     Update the Github token.
- \`gh_update_email\`:     Update the Github email.
- \`gh_update_username\`:  Update the Github username.
- \`host \$@\`:             Evaluates args as a command on the host machine. Try: \`host uname\`.
EOF
}

__bashrc__fn__print_about_shell() {
  cat <<EOF
- SHELL: BASH
- PWD: ${PWD}
- HOME: ${HOME}
- BASH_VERSION: ${BASH_VERSION}
- DISTRO: $(lsb_release -d | cut -f2)
- TERM: ${TERM}
EOF
}

__bashrc__fn__print_customizations() {
  cat <<EOF
- User managed rcfile: ~/.solos/.bashrc
- SolOS internal rcfile: ~/.solos/src/bin/profile/bashrc.sh
- Secrets: ~/.solos/secrets
- Source code: ~/.solos/src
EOF
}

__bashrc__fn__print_man() {
  cat <<EOF
Available commands:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
$(__bashrc__fn__print_commands)

Shell information:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
$(__bashrc__fn__print_about_shell)

Customization instructions:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
$(__bashrc__fn__print_customizations)

Source code:
$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)
https://github.com/interbolt/solos
EOF
}

__bashrc__fn__welcome_message() {
  # Make the CLI prompt pretty.
  cat <<EOF

Welcome to the SolOS Shell!

$(__bashrc__fn__print_man)

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo -e "\033[0;32mLogged in to Github ${gh_status_line} \033[0m"
  echo ""
}

__bashrc__fn__setup() {
  local warnings=()
  mkdir -p "${HOME}/.solos/secrets"
  local gh_token_file="${HOME}/.solos/secrets/gh_token"
  if [[ ! -f ${gh_token_path} ]]; then
    pkg.gum.github_token >"${gh_token_path}" || exit 1
  fi
  local gh_cmd_available=false
  if command -v gh >/dev/null 2>&1; then
    gh_cmd_available=true
  fi
  if [[ ${gh_cmd_available} = false ]]; then
    warnings+=("The 'gh' command is not available. This shell is not authenticated with Git.")
  elif [[ ! -f ${gh_token_file} ]]; then
    warnings+=("The 'gh' command is available but no token was found at ${gh_token_file}.")
  elif ! gh auth login --with-token <"${gh_token_file}" >/dev/null; then
    warnings+=("Failed to authenticate with Git.")
  elif ! gh auth setup-git 2>/dev/null; then
    warnings+=("Failed to setup Git.")
  fi
  if [[ -f "/etc/bash_completion" ]]; then
    . /etc/bash_completion
  else
    warnings+=("/etc/bash_completion not found. Bash completions will not be available.")
  fi
  local gh_email="$(host git config --global user.email)"
  local gh_user="$(host git config --global user.name)"
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
}

__bashrc__fn__preeval() {
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

__bashrc__fn__source_and_set_cwd

PS1='\[\033[0;32m\](SolOS:Debian)\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '

__bashrc__fn__setup
__bashrc__fn__welcome_message
preexec_functions+=("__bashrc__fn__preeval")

# Custom completions.
_custom_command_completions() {
  local cur prev words cword
  _init_completion || return
  _command_offset 1
}
complete -F _custom_command_completions rag

# Public functions.
gh_update_token() {
  local tmp_file="$(mktemp -q)"
  local gh_token_path="${HOME}/.solos/secrets/gh_token"
  pkg.gum.github_token >"${tmp_file}" || exit 1
  gh_token=$(cat "${tmp_file}")
  if gh auth login --with-token <"${tmp_file}" >/dev/null; then
    echo "Successfully updated the Github token."
    # Wait for a successful login before saving it.
    echo "${gh_token}" >"${gh_token_path}"
    gh auth status
  fi
}
gh_update_email() {
  local tmp_file="$(mktemp -q)"
  pkg.gum.github_email >"${tmp_file}" || exit 1
  local gh_email=$(cat "${tmp_file}")
  git config --global user.email "${gh_email}"
  host git config --global user.email "${gh_email}"
}
gh_update_username() {
  local tmp_file="$(mktemp -q)"
  pkg.gum.github_username >"${tmp_file}" || exit 1
  local gh_username=$(cat "${tmp_file}")
  git config --global user.name "${gh_username}"
  host git config --global user.name "${gh_username}"
}
code() {
  local bin_path="$(host which code)"
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
