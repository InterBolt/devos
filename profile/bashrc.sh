#!/usr/bin/env bash

shopt -s extdebug

. "${HOME}/.solos/src/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1
. "${HOME}/.solos/src/profile/rag.sh" || exit 1
. "${HOME}/.solos/src/profile/bash-preexec.sh" || exit 1
. "${HOME}/.solos/src/profile/table-outputs.sh" || exit 1

if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
fi

__bashrc__fn__users_home_dir() {
  local home_dir_saved_location="${HOME}/.solos/store/users_home_dir"
  if [[ ! -f ${home_dir_saved_location} ]]; then
    echo "Unexpected error: the user's home directory is not saved at: ${home_dir_saved_location}." >&2
    sleep 5
    exit 1
  fi
  cat "${home_dir_saved_location}" 2>/dev/null | head -n1
}

__bashrc__fn__extract_help_description() {
  local help_output=$(cat)
  if [[ -z ${help_output} ]]; then
    echo "Unexpected error: empty help output." >&2
    return 1
  fi
  local description_line_number=$(echo "${help_output}" | grep -n "^DESCRIPTION:" | cut -d: -f1)
  if [[ -z ${description_line_number} ]]; then
    echo "Unexpected error: invalid help output format. Could not find a line starting with \`DESCRIPTION:\`" >&2
    return 1
  fi
  local first_description_line=$((description_line_number + 2))
  if [[ -z $(echo "${help_output}" | sed -n "${first_description_line}p") ]]; then
    echo "Unexpected error: invalid help output format. No text was found on the second line after DESCRIPTION:" >&2
    return 1
  fi
  echo "${help_output}" | cut -d$'\n' -f"${first_description_line}"
}

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
  local done_file="${HOME}/.solos/.relay.done"
  local command_file="${HOME}/.solos/.relay.command"
  local stdout_file="${HOME}/.solos/.relay.stdout"
  local stderr_file="${HOME}/.solos/.relay.stderr"
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

__bashrc__fn__print_man() {
  local solos_bin_cmds=()
  while IFS= read -r -d $'\0' file; do
    local cmd_name="$(basename "${file}" | cut -d. -f1)"
    solos_bin_cmds+=("${cmd_name}_solos" "$("${cmd_name}_solos" --help | __bashrc__fn__extract_help_description)")
  done < <(find "${HOME}/.solos/src/path-commands/" -type f -print0)

  cat <<EOF

$(
    __table_outputs__fn__format \
      "PATH_COMMAND,DESCRIPTION" \
      "${solos_bin_cmds[@]}"
  )

$(
    __table_outputs__fn__format \
      "SHELL_COMMAND,DESCRIPTION" \
      rag "$(rag --help | __bashrc__fn__extract_help_description)" \
      host "$(host --help | __bashrc__fn__extract_help_description)" \
      solos "$(solos --help | __bashrc__fn__extract_help_description)" \
      gh_token "$(gh_token --help | __bashrc__fn__extract_help_description)" \
      gh_email "$(gh_email --help | __bashrc__fn__extract_help_description)" \
      gh_name "$(gh_name --help | __bashrc__fn__extract_help_description)" \
      '-' "Runs its arguments as a command and avoids all rag-related stdout tracking."
  )
  
$(
    __table_outputs__fn__format \
      "RESOURCE,PATH" \
      'User managed rcfile' "$(__bashrc__fn__users_home_dir)/.solos/.bashrc" \
      'Internal rcfile' "$(__bashrc__fn__users_home_dir)/.solos/src/profile/bashrc.sh" \
      'Secrets' "$(__bashrc__fn__users_home_dir)/.solos/secrets" \
      'Logs' "$(__bashrc__fn__users_home_dir)/.solos/logs" \
      'Captured notes and stdout' "$(__bashrc__fn__users_home_dir)/.solos/rag" \
      'Host <=> Container relay' "$(__bashrc__fn__users_home_dir)/.solos/relay" \
      'Store' "$(__bashrc__fn__users_home_dir)/.solos/store"
  )
  
$(
    __table_outputs__fn__format \
      "SHELL_PROPERTY,VALUE" \
      "Shell" "BASH" \
      "Working Dir" "${PWD/#${HOME}/$(__bashrc__fn__users_home_dir)}" \
      "Bash Version" "${BASH_VERSION}" \
      "Container OS" "$(lsb_release -d | cut -f2)" \
      "SolOS Source Code" "https://github.com/interbolt/solos"
  )

$(
    __table_outputs__fn__format \
      "LEGEND_KEY,LEGEND_DESCRIPTION" \
      "PATH_COMMAND" "Commands that are available in the container's PATH (meaning any bash script can use them). All path commands end in '_solos' to avoid conflicts and are defined at \`~/.solos/src/path-commands\`." \
      "SHELL_COMMAND" "Commands that are ONLY available in the SolOS shell." \
      "RESOURCE" "Relevant directories and files created and/or managed by SolOS." \
      "SHELL_PROPERTY" "These properties describe various aspects of the SolOS shell."
  )
EOF
}

__bashrc__fn__print_welcome_manual() {
  # This should say "Welcome to SolOS" in ASCII art.
  local asci_welcome_to_solos_art=$(
    cat <<EOF
    
   _____       _  ____   _____ 
  / ____|     | |/ __ \ / ____|
 | (___   ___ | | |  | | (___  
  \___ \ / _ \| | |  | |\___ \ 
  ____) | (_) | | |__| |____) |
 |_____/ \___/|_|\____/|_____/ 
                               
EOF
  )

  cat <<EOF
${asci_welcome_to_solos_art}
$(__bashrc__fn__print_man)

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo ""
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

do_processing() {
  local captured_stdout_file="${HOME}/.solos/rag/.captured_stdout"
  local captured_stderr_file="${HOME}/.solos/rag/.captured_stderr"
  local captured_cmd_file="${HOME}/.solos/rag/.captured_cmd"
  local captured_rag_stdout_file="${HOME}/.solos/rag/.captured_rag_stdout"
  local captured_rag_stderr_file="${HOME}/.solos/rag/.captured_rag_stderr"

  echo "CATTING ${captured_stdout_file}"
  cat "${captured_stdout_file}"
  echo "CATTING ${captured_stderr_file}"
  cat "${captured_stderr_file}"
  echo "CATTING ${captured_cmd_file}"
  cat "${captured_cmd_file}"
  echo "CATTING ${captured_rag_stdout_file}"
  cat "${captured_rag_stdout_file}"
  echo "CATTING ${captured_rag_stderr_file}"
  cat "${captured_rag_stderr_file}"
  echo "DONE CATTING"
}

__bashrc__fn__preexec_shell() {
  local cmd="${*}"
  if [[ ${cmd} = "exit" ]]; then
    eval "${cmd}"
    return $?
  fi
  if [[ ${cmd} = "host "* ]]; then
    eval "${cmd}"
    return $?
  fi
  if [[ ${cmd} = "cd "* ]]; then
    eval "${cmd}"
    return $?
  fi
  if [[ ${cmd} = "- "* ]]; then
    eval ''"${cmd/- /}"''
    return $?
  fi
  if [[ ${cmd} = "cd" ]]; then
    eval "${cmd}"
    return $?
  fi
  if [[ ${cmd} = "clear" ]]; then
    eval "${cmd}"
    return $?
  fi
  if [[ ${cmd} = "rag captured" ]]; then
    local line_count="$(wc -l <"${HOME}/.solos/rag/captured.log")"
    code -g "${HOME}/.solos/rag/captured:${line_count}"
    return $?
  fi
  if [[ ${cmd} = "rag notes" ]]; then
    local line_count="$(wc -l <"${HOME}/.solos/rag/notes.log")"
    code -g "${HOME}/.solos/rag/notes:${line_count}"
    return $?
  fi
  if [[ ${cmd} = "code "* ]]; then
    eval "${cmd}"
    return $?
  fi
  if [[ ${cmd} = "rag "* ]]; then
    eval "${cmd}"
    return $?
  fi
  local return_code=0
  {
    local captured_stdout_file="${HOME}/.solos/rag/.captured_stdout"
    local captured_stderr_file="${HOME}/.solos/rag/.captured_stderr"
    local captured_cmd_file="${HOME}/.solos/rag/.captured_cmd"
    local captured_rag_stdout_file="${HOME}/.solos/rag/.captured_rag_stdout"
    local captured_rag_stderr_file="${HOME}/.solos/rag/.captured_rag_stderr"
    rm -f \
      "${captured_stdout_file}" \
      "${captured_stderr_file}" \
      "${captured_cmd_file}" \
      "${captured_rag_stdout_file}" \
      "${captured_rag_stderr_file}"
    echo "${cmd}" >"${captured_cmd_file}"
    exec \
      > >(tee >(grep "^\[RAG\]" >>"${captured_rag_stdout_file}") "${captured_stdout_file}") \
      2> >(tee >(grep "^\[RAG\]" >>"${captured_rag_stderr_file}") "${captured_stderr_file}" >&2)
    eval "${cmd}"
    return_code=$?
  } | cat

  return ${return_code}
}

__bashrc__fn__main() {
  # Handle the case where this rcfile is sourced from an app context.
  while [[ $# -gt 0 ]]; do
    if [[ ${1} = "--with-app-context" ]]; then
      preexec=__bashrc__fn__preeexec_app_context
      exit 0
    fi
  done
  # Do a bunch of setup stuff
  __bashrc__fn__ide_shell
  # Add preeval logic which will ensure that the stdout lines starting with [RAG] are captured.
  # A few things like cd, exit, and host commands are ignored.
  preexec=__bashrc__fn__preexec_shell
  __bash_preexec__fn__main
}

# Public stuff
rag() {
  __rag__fn__main "$@"
}
host() {
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF

USAGE: host ...<any command here>...

DESCRIPTION:

Any command that you run with 'host' prefix will be executed on the host machine.

Try running 'host uname' to see the output of the 'uname' command on your host machine.

The \`host\` command doesn't use unix pipes. Rather, the SolOS shell starts a background process upon launch \
which periodically checks a specific txt file for a new command from the docker container. Once the background process detects a new command \
it executes it (on the host) and writes stdout and stderr to some more specific txt files. \
The SolOS shell (in the container) then reads the stdout/err from those files and displays the output in the terminal.

EOF
    return 0
  fi
  __bashrc__fn__host "$@"
}
gh_token() {
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
USAGE: gh_token

DESCRIPTION:

Update the Github token.

EOF
    return 0
  fi
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
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
USAGE: gh_email

DESCRIPTION:

Update the Github email.

EOF
    return 0
  fi
  local tmp_file="$(mktemp -q)"
  gum_github_email >"${tmp_file}" || exit 1
  local gh_email=$(cat "${tmp_file}")
  git config --global user.email "${gh_email}"
  host git config --global user.email "${gh_email}"
}
gh_name() {
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
USAGE: gh_name

DESCRIPTION:

Update the Github username.

EOF
    return 0
  fi
  local tmp_file="$(mktemp -q)"
  gum_github_name >"${tmp_file}" || exit 1
  local gh_name=$(cat "${tmp_file}")
  git config --global user.name "${gh_name}"
  host git config --global user.name "${gh_name}"
}
code() {
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
USAGE: code <...vscode cli args...>

DESCRIPTION:

Opens the Visual Studio Code editor from the host machine.

EOF
    return 0
  fi
  local bin_path="$(__bashrc__fn__host which code)"
  host "${bin_path}" "${*}"
}
solos() {
  local executable_path="${HOME}/.solos/src/cli/solos.sh"
  bash "${executable_path}" "$@"
}
dsolos() {
  local executable_path="${HOME}/.solos/src/cli/solos.sh"
  bash "${executable_path}" --restricted-developer "$@"
}
man() {
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
USAGE: man

DESCRIPTION:

Print info about this shell.

EOF
    return 0
  fi
  echo ""
  __bashrc__fn__print_man
  echo ""
}

__bashrc__fn__main "$@"

# read and intercept every command before it is executed

# set -x
# set -v
