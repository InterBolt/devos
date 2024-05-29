#!/usr/bin/env bash

shopt -s extdebug

. "${HOME}/.solos/src/tools/log.sh" || exit 1
. "${HOME}/.solos/src/tools/pkgs/gum.sh" || exit 1
. "${HOME}/.solos/src/container/profile-rag.sh" || exit 1
. "${HOME}/.solos/src/container/profile-table-outputs.sh" || exit 1

__profile_bashrc__relay_dir="${HOME}/.solos/.relay"

if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
fi

__profile_bashrc__fn__users_home_dir() {
  local home_dir_saved_location="${HOME}/.solos/store/users_home_dir"
  if [[ ! -f ${home_dir_saved_location} ]]; then
    echo "Unexpected error: the user's home directory is not saved at: ${home_dir_saved_location}." >&2
    sleep 5
    exit 1
  fi
  cat "${home_dir_saved_location}" 2>/dev/null | head -n1
}

__profile_bashrc__fn__extract_help_description() {
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

__profile_bashrc__fn__bash_completions() {
  _custom_command_completions() {
    local cur prev words cword
    _init_completion || return
    _command_offset 1
  }
  complete -F _custom_command_completions rag
  complete -F _custom_command_completions host
  complete -F _custom_command_completions '-'
}

__profile_bashrc__fn__host() {
  mkdir -p "${__profile_bashrc__relay_dir}"

  local done_file="${__profile_bashrc__relay_dir}/done"
  local command_file="${__profile_bashrc__relay_dir}/command"
  local stdout_file="${__profile_bashrc__relay_dir}/stdout"
  local stderr_file="${__profile_bashrc__relay_dir}/stderr"
  local cmd=''"${*}"''
  rm -f "${stdout_file}"
  echo "" >"${done_file}"
  echo "" >"${stderr_file}"
  echo "" >"${stdout_file}"
  echo ''"${cmd}"'' >"${command_file}"
  while [[ $(cat "${done_file}" 2>/dev/null || echo "") != "DONE:"* ]]; do
    sleep 0.1
  done
  local return_code=$(cat "${done_file}" 2>/dev/null | cut -d: -f2)
  stdout="$(cat "${stdout_file}" 2>/dev/null || echo "")"
  stderr="$(cat "${stderr_file}" 2>/dev/null || echo "")"
  rm -f "${done_file}" "${command_file}" "${stdout_file}" "${stderr_file}"
  if [[ -n ${stdout} ]]; then
    echo "${stdout}"
  fi
  if [[ -n ${stderr} ]]; then
    echo "${stderr}" >&2
  fi
  return ${return_code}
}

__profile_bashrc__fn__print_info() {
  local solos_bin_cmds=()
  while IFS= read -r -d $'\0' file; do
    local cmd_name="$(basename "${file}" | cut -d. -f1)"
    solos_bin_cmds+=("${cmd_name}_solos" "$("${cmd_name}_solos" --help | __profile_bashrc__fn__extract_help_description)")
  done < <(find "${HOME}/.solos/src/tools/cmds/" -type f -print0)

  cat <<EOF

$(
    __profile_table_outputs__fn__format \
      "PATH_COMMAND,DESCRIPTION" \
      "${solos_bin_cmds[@]}"
  )

$(
    __profile_table_outputs__fn__format \
      "SHELL_COMMAND,DESCRIPTION" \
      '-' "Runs its arguments as a command and avoids all rag-related stdout tracking." \
      info "Print info about this shell." \
      rag "$(rag --help | __profile_bashrc__fn__extract_help_description)" \
      host "$(host --help | __profile_bashrc__fn__extract_help_description)" \
      solos "$(solos --help | __profile_bashrc__fn__extract_help_description)" \
      gh_token "$(gh_token --help | __profile_bashrc__fn__extract_help_description)" \
      gh_email "$(gh_email --help | __profile_bashrc__fn__extract_help_description)" \
      gh_name "$(gh_name --help | __profile_bashrc__fn__extract_help_description)" \
      preexec_list "$(preexec_list --help | __profile_bashrc__fn__extract_help_description)" \
      preexec_add "$(preexec_add --help | __profile_bashrc__fn__extract_help_description)" \
      preexec_remove "$(preexec_remove --help | __profile_bashrc__fn__extract_help_description)" \
      postexec_list "$(postexec_list --help | __profile_bashrc__fn__extract_help_description)" \
      postexec_add "$(postexec_add --help | __profile_bashrc__fn__extract_help_description)" \
      postexec_remove "$(postexec_remove --help | __profile_bashrc__fn__extract_help_description)"
  )
  
$(
    __profile_table_outputs__fn__format \
      "RESOURCE,PATH" \
      'User managed rcfile' "$(__profile_bashrc__fn__users_home_dir)/.solos/.bashrc" \
      'Internal rcfile' "$(__profile_bashrc__fn__users_home_dir)/.solos/src/container/profile-bashrc.sh" \
      'Logs' "$(__profile_bashrc__fn__users_home_dir)/.solos/logs" \
      'Captured notes and stdout' "$(__profile_bashrc__fn__users_home_dir)/.solos/rag" \
      'Global Store' "$(__profile_bashrc__fn__users_home_dir)/.solos/store" \
      'Project Stores' "$(__profile_bashrc__fn__users_home_dir)/.solos/projects/<project>/store" \
      'Global Secrets' "$(__profile_bashrc__fn__users_home_dir)/.solos/secrets" \
      'Project Secrets' "$(__profile_bashrc__fn__users_home_dir)/.solos/projects/<project>/secrets"
  )
  
$(
    __profile_table_outputs__fn__format \
      "SHELL_PROPERTY,VALUE" \
      "Shell" "BASH" \
      "Mounted Volume" "$(__profile_bashrc__fn__users_home_dir)/.solos" \
      "Bash Version" "${BASH_VERSION}" \
      "Container OS" "$(lsb_release -d | cut -f2)" \
      "SolOS Repo" "https://github.com/interbolt/solos"
  )

$(
    __profile_table_outputs__fn__format \
      "LEGEND_KEY,LEGEND_DESCRIPTION" \
      "PATH_COMMAND" "Commands that are available in the container's PATH (meaning any bash script can use them). All path commands end in '_solos' to avoid conflicts and are defined at \`~/.solos/src/tools/cmds\`." \
      "SHELL_COMMAND" "Commands that are ONLY available in the SolOS shell." \
      "RESOURCE" "Relevant directories and files created and/or managed by SolOS." \
      "SHELL_PROPERTY" "These properties describe various aspects of the SolOS shell."
  )
EOF
}

__profile_bashrc__fn__print_welcome_manual() {
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
$(__profile_bashrc__fn__print_info)

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo ""
  echo -e "\033[0;32mLogged in to Github ${gh_status_line} \033[0m"
  echo ""
}

__profile_bashrc__fn__install() {
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
  local gh_email="$(__profile_bashrc__fn__host git config --global user.email)"
  local gh_user="$(__profile_bashrc__fn__host git config --global user.name)"
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
  __profile_bashrc__fn__print_welcome_manual
  __profile_bashrc__fn__bash_completions
}

__profile_bashrc__fn__reserved_fn_protection() {
  if [[ ${1} = "--solos-reserved" ]]; then
    return 1
  fi
}

# PUBLIC FUNCTIONS:

user_preexecs=()
user_postexecs=()

pub_rag() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  __profile_rag__fn__main "$@"
}
pub_host() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} == "--help" ]]; then
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
  local return_code=0
  if ! __profile_bashrc__fn__host "$@"; then
    return_code="$?"
  fi
  rm -f \
    "${__profile_bashrc__relay_dir}/done" \
    "${__profile_bashrc__relay_dir}/command" \
    "${__profile_bashrc__relay_dir}/stdout" \
    "${__profile_bashrc__relay_dir}/stderr" 2>/dev/null
  rm -d "${__profile_bashrc__relay_dir}" 2>/dev/null
  return ${return_code}
}
pub_gh_token() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} == "--help" ]]; then
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
pub_gh_email() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151
  if [[ ${1} == "--help" ]]; then
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
pub_gh_name() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} == "--help" ]]; then
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
pub_code() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151
  if [[ ${1} == "--help" ]]; then
    cat <<EOF
USAGE: code <...vscode cli args...>

DESCRIPTION:

Opens the Visual Studio Code editor from the host machine.

EOF
    return 0
  fi
  local bin_path="$(__profile_bashrc__fn__host which code)"
  host "${bin_path}" "${*}"
}
pub_solos() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  local executable_path="${HOME}/.solos/src/container/cli.sh"
  bash "${executable_path}" "$@"
}
pub_info() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
USAGE: info

DESCRIPTION:

Print info about this shell.

EOF
    return 0
  fi
  echo ""
  __profile_bashrc__fn__print_info
  echo ""
}
pub_preexec_list() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151
  if [[ ${1} = "--help" ]]; then
    cat <<EOF
USAGE: preexec_list

DESCRIPTION:

List all user-defined preexec functions.

EOF
    return 0
  fi
  echo "${user_preexecs[@]}"
}
pub_preexec_add() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} = "--help" ]]; then
    cat <<EOF
USAGE: preexec_add <function_name>

DESCRIPTION:

Add a user-defined preexec function.
EOF
    return 0
  fi
  local fn="${1}"
  if [[ -z ${fn} ]]; then
    echo "preexec: missing function name" >&2
    return 1
  fi
  if ! declare -f "${fn}" >/dev/null; then
    echo "preexec: function '${fn}' not found" >&2
    return 1
  fi
  if [[ " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
    echo "preexec: function '${fn}' already exists in user_preexecs" >&2
    return 1
  fi
  user_preexecs+=("${fn}")
}
pub_preexec_remove() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} = "--help" ]]; then
    cat <<EOF
USAGE: preexec_remove <function_name>

DESCRIPTION:

Remove a user-defined preexec function.

EOF
    return 0
  fi
  local fn="${1}"
  if [[ ! " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
    echo "Invalid usage: preexec: function '${fn}' not found in user_preexecs" >&2
    return 1
  fi
  user_preexecs=("${user_preexecs[@]/${fn}/}")
}
pub_postexec_list() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} = "--help" ]]; then
    cat <<EOF
USAGE: postexec_list

DESCRIPTION:

List all user-defined postexec functions.

EOF
    return 0
  fi
  echo "${user_postexecs[@]}"
}
pub_postexec_add() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} = "--help" ]]; then
    cat <<EOF
USAGE: postexec_add <function_name>

DESCRIPTION:

Add a user-defined postexec function.
EOF
    return 0
  fi
  local fn="${1}"
  if [[ -z ${fn} ]]; then
    echo "postexec: missing function name" >&2
    return 1
  fi
  if ! declare -f "${fn}" >/dev/null; then
    echo "postexec: function '${fn}' not found" >&2
    return 1
  fi
  if [[ " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
    echo "postexec: function '${fn}' already exists in user_postexecs" >&2
    return 1
  fi
  user_postexecs+=("${fn}")
}
pub_postexec_remove() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151

  if [[ ${1} = "--help" ]]; then
    cat <<EOF
USAGE: postexec_remove <function_name>

DESCRIPTION:

Remove a user-defined postexec function.

EOF
    return 0
  fi
  local fn="${1}"
  if [[ ! " ${user_postexecs[@]} " =~ " ${fn} " ]]; then
    echo "Invalid usage: postexec: function '${fn}' not found in user_postexecs" >&2
    return 1
  fi
  user_postexecs=("${user_postexecs[@]/${fn}/}")
}
pub_install_solos() {
  __profile_bashrc__fn__reserved_fn_protection "$@" || return 151
  # Prevent a user from defining their own versions of the built-in public functions defined in this script.
  # Each public function will return 151 when the --solos-reserved flag is passed, which allows us to quickly test whether
  # or not a function was defined here or in the user's script. This depends on the assumption that the user will not implement
  # support for --solos-reserved and the 151 return code in their own functions. But that's a safe assumption and if they do
  # then we should assume they know what they're doing.
  # Note: since we do this in the installation command, the user is free to overwrite public functions if they don't plan
  # to install the SolOS shell.
  local overwritten_fns=()
  for func in ${__profile_bashrc__pub_fns}; do
    new_func_name="${func#pub_}"
    solos_overwrite_return_code_check="$(eval ''"${new_func_name}"' --solos-reserved' >/dev/null 2>&1 && echo "$?" || echo "$?")"
    if [[ ${solos_overwrite_return_code_check} -ne 151 ]]; then
      overwritten_fns+=("${new_func_name}")
    fi
  done

  if [[ ${overwritten_fns} ]]; then
    local newline=$'\n'
    local message="The following functions are reserved in the SolOS shell:"
    local message_length=${#message}
    gum_danger_box "${message}${newline}$(printf '%*s\n' "${message_length}" '' | tr ' ' -)${newline}${overwritten_fns[@]}"
    trap 'exit 1;' SIGINT
    echo "Press enter to exit the shell."
    read -r || exit 1
    exit 1
  fi

  __profile_bashrc__fn__install
  __profile_rag__fn__install
}

__profile_bashrc__pub_fns="$(declare -F | grep -o "pub_[a-zA-Z_]*" | xargs)"
for func in ${__profile_bashrc__pub_fns}; do
  new_func_name="${func#pub_}"
  # Ensure that each pub_* function is available without the pub_ prefix.
  eval "${new_func_name}() { ${func} \"\$@\"; return \"\$?\"; }"
done
