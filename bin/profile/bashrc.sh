#!/usr/bin/env bash

__bashrc__var__self="${BASH_SOURCE[0]}"
__bashrc__var__ENTRY_PWD="${PWD}"
cd "${HOME}/.solos/src/bin" || exit 1
. pkg/__source__.sh || exit 1
. profile/rag.sh || exit 1
. external/bash-preexec.sh || exit 1
. profile/host.sh || exit 1
cd "${__bashrc__var__ENTRY_PWD}" || exit 1

__bashrc__var__warnings=()

if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
fi
__var__LAUNCH_PWD="${PWD}"
PS1='\[\033[0;32m\](SolOS:Debian)\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '

if command -v gh >/dev/null 2>&1; then
  __var__GH_AVAILABLE=true
else
  __var__GH_AVAILABLE=false
fi
__var__GH_TOKEN_FILE="${HOME}/.solos/secrets/gh_token"
if [[ ${__var__GH_AVAILABLE} = false ]]; then
  __bashrc__var__warnings+="The 'gh' command is not available. This shell is not authenticated with Git."
elif [[ ! -f ${__var__GH_TOKEN_FILE} ]]; then
  __bashrc__var__warnings+="The 'gh' command is available but no token was found at ${__var__GH_TOKEN_FILE}."
elif ! gh auth login --with-token <"${__var__GH_TOKEN_FILE}" >/dev/null; then
  __bashrc__var__warnings+="Failed to authenticate with Git."
fi
if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
else
  __bashrc__var__warnings+="/etc/bash_completion not found. Bash completions will not be available."
fi
if [[ ${__bashrc__var__warnings} ]]; then
  for warning in "${__bashrc__var__warnings[@]}"; do
    echo -e "\033[0;31mWARNING:\033[0m ${warning}"
  done
else
  __bashrc__var__path_to_this_script="${HOME}/.solos/src/bin/profile/bashrc.sh"
  cat <<EOF

Welcome to the SolOS integrated VSCode terminal.

The following commands are available:

- \`rag\`: Take notes and intelligently capture stdout. See \`rag --help\`.
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
  __bashrc__var__gh_status_line="$(gh auth status | grep "Logged in")"
  __bashrc__var__gh_status_line="${__bashrc__var__gh_status_line##*" "}"
  echo -e "\033[0;32mLogged in to Github ${__bashrc__var__gh_status_line} \033[0m"
  echo ""
fi

code() {
  local bin_path="$(host which code)"
  host "${bin_path}" "${*}"
}

shopt -s extdebug

__bashrc__fn__cmd_proxy() {
  if [[ ${BASH_COMMAND} = "exit" ]]; then
    return 0
  fi
  if [[ ${BASH_COMMAND} = "cd "* ]]; then
    return 0
  fi
  if [[ ${BASH_COMMAND} = "cd" ]]; then
    return 0
  fi
  if [[ ${BASH_COMMAND} = "rag captured" ]]; then
    local line_count="$(wc -l <"${HOME}/.solos/rag/captured")"
    code -g "${HOME}/.solos/rag/captured:${line_count}"
    return 1
  fi
  if [[ ${BASH_COMMAND} = "rag notes" ]]; then
    local line_count="$(wc -l <"${HOME}/.solos/rag/notes")"
    code -g "${HOME}/.solos/rag/notes:${line_count}"
    return 1
  fi
  if [[ ${BASH_COMMAND} = "code "* ]]; then
    return 0
  fi
  if [[ ${BASH_COMMAND} = "rag "* ]]; then
    return 0
  fi
  rag --captured-only ''"${BASH_COMMAND}"''
  return 1
}

preexec_functions+=("__bashrc__fn__cmd_proxy")
