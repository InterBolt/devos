#!/usr/bin/env bash

shopt -s extdebug

__bashrc__var__self="${BASH_SOURCE[0]}"

__bashrc__fn__source_and_set_cwd() {
  local entry_pwd="${PWD}"
  # Be paranoid about the current working directory before sourcing anything.
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

__bashrc__fn__welcome_message() {
  # Make the CLI prompt pretty.
  cat <<EOF

Welcome to the SolOS integrated VSCode terminal.

The following commands are available:

- \`rag\`: Take notes and capture stdout lines starting with \`[RAG]*\`. See \`rag --help\`.
- \`solos\`: A CLI utility for managing deployment servers. See \`solos --help\`.
- \`host\`: A utility for evaluating commands on your host machine. Use with caution!

Considerations:

- The SolOS custom commands are only available to shells that source: ${__bashrc__var__self/'/root'/"~"}
- Bash completions are installed and available.
- Bash version is 5.2
- The docker CLI will use your host's daemon.

Known limitations:

- The container will always use Debian
- No support out of the box for zsh, fish, or other shells.

Customize:

- Customize this shell via: ~/.solos/.bashrc
- Modify the SolOS source code: ~/.solos/src

Github repository: https://github.com/interbolt/solos

Type \`exit\` to leave the SolOS shell.

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo -e "\033[0;32mLogged in to Github ${gh_status_line} \033[0m"
  echo ""
}

__bashrc__fn__setup() {
  local warnings=()
  local gh_token_file="${HOME}/.solos/secrets/gh_token"
  local gh_cmd_available=false
  if command -v gh >/dev/null 2>&1; then
    gh_cmd_available=true
  fi
  if [[ ${gh_cmd_available} = false ]]; then
    warnings+="The 'gh' command is not available. This shell is not authenticated with Git."
  elif [[ ! -f ${gh_token_file} ]]; then
    warnings+="The 'gh' command is available but no token was found at ${gh_token_file}."
  elif ! gh auth login --with-token <"${gh_token_file}" >/dev/null; then
    warnings+="Failed to authenticate with Git."
  elif ! gh auth setup-git 2>/dev/null; then
    warnings+="Failed to setup Git."
  fi
  if [[ -f "/etc/bash_completion" ]]; then
    . /etc/bash_completion
  else
    warnings+="/etc/bash_completion not found. Bash completions will not be available."
  fi

  if [[ ${warnings} ]]; then
    for warning in "${warnings[@]}"; do
      echo -e "\033[0;31mWARNING:\033[0m ${warning}"
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
  rag --captured-only ''"${BASH_COMMAND}"''
  return 1
}

__bashrc__fn__source_and_set_cwd

PS1='\[\033[0;32m\](SolOS:Debian)\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '

__bashrc__fn__setup
__bashrc__fn__welcome_message
preexec_functions+=("__bashrc__fn__preeval")

# Public functions for the user.
code() {
  local bin_path="$(host which code)"
  host "${bin_path}" "${*}"
}

welcome() {
  __bashrc__fn__welcome_message
}

_custom_command_completions() {
  local cur prev words cword
  _init_completion || return
  _command_offset 1
}

complete -F _custom_command_completions rag

git config --global user.email "$(host git config --global user.email)"
git config --global user.user "$(host git config --global user.user)"
