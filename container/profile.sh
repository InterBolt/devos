#!/usr/bin/env bash

# Skip command if we get an unsuccessful return code in the debug trap.
shopt -s extdebug

# When the shell exits, append to the history file instead of overwriting it.
shopt -s histappend
# Avoid duplicate entries.
HISTCONTROL=ignoredups:erasedups
# Load this history file.
history -r

. "${HOME}/.solos/src/pkgs/log.sh" || exit 1
. "${HOME}/.solos/src/pkgs/gum.sh" || exit 1
. "${HOME}/.solos/src/container/profile-tag.sh" || exit 1
. "${HOME}/.solos/src/container/profile-table-outputs.sh" || exit 1

__profile__pub_fns=""
__profile__relay_dir="${HOME}/.solos/.relay"
__profile__loaded_project=""

if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
fi

export PARENT_SHELL_PID="${PARENT_SHELL_PID:-"$$"}"

__profile__fn__error_press_enter() {
  echo "Press enter to exit..."
  read -r || exit 1
  exit 1
}

__profile__fn__users_home_dir() {
  local home_dir_saved_location="${HOME}/.solos/store/users_home_dir"
  if [[ ! -f ${home_dir_saved_location} ]]; then
    log_error "Unexpected error: the user's home directory is not saved at: ${home_dir_saved_location}."
    __profile__fn__error_press_enter
  fi
  cat "${home_dir_saved_location}" 2>/dev/null | head -n1
}

__profile__fn__extract_help_description() {
  local help_output=$(cat)
  if [[ -z ${help_output} ]]; then
    log_error "Unexpected error: empty help output."
    return 1
  fi
  local description_line_number=$(echo "${help_output}" | grep -n "^DESCRIPTION:" | cut -d: -f1)
  if [[ -z ${description_line_number} ]]; then
    log_error "Unexpected error: invalid help output format. Could not find a line starting with \`DESCRIPTION:\`"
    return 1
  fi
  local first_description_line=$((description_line_number + 2))
  if [[ -z $(echo "${help_output}" | sed -n "${first_description_line}p") ]]; then
    log_error "Unexpected error: invalid help output format. No text was found on the second line after DESCRIPTION:"
    return 1
  fi
  echo "${help_output}" | cut -d$'\n' -f"${first_description_line}"
}

__profile__fn__bash_completions() {
  _custom_command_completions() {
    local cur prev words cword
    _init_completion || return
    _command_offset 1
  }
  complete -F _custom_command_completions tag
  complete -F _custom_command_completions host
  complete -F _custom_command_completions '-'
}

__profile__fn__run_checked_out_project_script() {
  local checked_out_project="$(cat "${HOME}/.solos/store/checked_out_project" 2>/dev/null || echo "" | head -n 1)"
  if [[ -z ${checked_out_project} ]]; then
    return 0
  fi
  local projects_dir="${HOME}/.solos/projects"
  local project_dir="${projects_dir}/${checked_out_project}"
  if [[ ! ${PWD} =~ ^${project_dir} ]] && [[ ${PWD} != ${projects_dir} ]] && [[ ${PWD} =~ ^${projects_dir} ]]; then
    local pwd_project="$(basename "${PWD}")"
    echo "The checked out project does not match the project of your terminal's working directory." >&2
    echo "Run \`solos checkout ${pwd_project}\` in your host terminal to ensure VSCode can load the correct container when launching the SolOS shell." >&2
    __profile__fn__error_press_enter
  fi
  if [[ ${PWD} =~ ^${project_dir} ]]; then
    local project_script="${HOME}/.solos/projects/${checked_out_project}/solos.checkout.sh"
    if [[ -f ${project_script} ]]; then
      . "${project_script}"
      __profile__loaded_project="${checked_out_project}"
      echo -e "\033[0;32mChecked out project: ${__profile__loaded_project} \033[0m"
    fi
  fi
}
__profile__fn__print_info() {
  local checked_out_project="$(cat "${HOME}/.solos/store/checked_out_project" 2>/dev/null || echo "" | head -n 1)"
  cat <<EOF

$(
    __profile_table_outputs__fn__format \
      "SHELL_COMMAND,DESCRIPTION" \
      '-' "Runs its arguments as a command and avoids all tag-related stdout tracking." \
      info "Print info about this shell." \
      reload "$(reload --help | __profile__fn__extract_help_description)" \
      tag "$(tag --help | __profile__fn__extract_help_description)" \
      solos "$(solos --help | __profile__fn__extract_help_description)" \
      preexec_list "$(preexec_list --help | __profile__fn__extract_help_description)" \
      preexec_add "$(preexec_add --help | __profile__fn__extract_help_description)" \
      preexec_remove "$(preexec_remove --help | __profile__fn__extract_help_description)" \
      postexec_list "$(postexec_list --help | __profile__fn__extract_help_description)" \
      postexec_add "$(postexec_add --help | __profile__fn__extract_help_description)" \
      postexec_remove "$(postexec_remove --help | __profile__fn__extract_help_description)"
  )

$(
    __profile_table_outputs__fn__format \
      "RESOURCE,PATH" \
      'Checked out project' "$(__profile__fn__users_home_dir)/.solos/projects/${checked_out_project}" \
      'User managed rcfile' "$(__profile__fn__users_home_dir)/.solos/profile/.bashrc" \
      'Internal rcfile' "$(__profile__fn__users_home_dir)/.solos/src/container/profile.sh" \
      'Config' "$(__profile__fn__users_home_dir)/.solos/config" \
      'Secrets' "$(__profile__fn__users_home_dir)/.solos/secrets"
  )

$(
    __profile_table_outputs__fn__format \
      "SHELL_PROPERTY,VALUE" \
      "Shell" "BASH" \
      "Mounted Volume" "$(__profile__fn__users_home_dir)/.solos" \
      "Bash Version" "${BASH_VERSION}" \
      "Container OS" "Debian 12" \
      "SolOS Repo" "https://github.com/interbolt/solos"
  )

$(
    __profile_table_outputs__fn__format \
      "LEGEND_KEY,LEGEND_DESCRIPTION" \
      "SHELL_COMMAND" "Commands that are ONLY available in the SolOS shell." \
      "RESOURCE" "Relevant directories and files created and/or managed by SolOS." \
      "SHELL_PROPERTY" "These properties describe various aspects of the SolOS shell."
  )
EOF
}

__profile__fn__print_welcome_manual() {
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
$(__profile__fn__print_info)

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo ""
  echo -e "\033[0;32mLogged in to Github ${gh_status_line} \033[0m"
  echo ""
}

__profile__fn__install_gh() {
  local secrets_path="${HOME}/.solos/secrets"
  local config_path="${HOME}/.solos/config"
  if [[ ! -d ${secrets_path} ]]; then
    log_error "No secrets directory found at ${secrets_path}. You probably need to run \`solos setup\`."
    __profile__fn__error_press_enter
  fi
  if [[ ! -d ${config_path} ]]; then
    log_error "No config directory found at ${config_path}. You probably need to run \`solos setup\`."
    __profile__fn__error_press_enter
  fi

  local gh_token_path="${secrets_path}/gh_token"
  local gh_name_path="${config_path}/gh_name"
  local gh_email_path="${config_path}/gh_email"
  if [[ ! -f ${gh_token_path} ]]; then
    log_error "No Github token found at ${gh_token_path}. You probably need to run \`solos setup\`."
    __profile__fn__error_press_enter
  fi
  if [[ ! -f ${gh_name_path} ]]; then
    log_error "No Github name found at ${gh_name_path}. You probably need to run \`solos setup\`."
    __profile__fn__error_press_enter
  fi
  if [[ ! -f ${gh_email_path} ]]; then
    log_error "No Github email found at ${gh_email_path}. You probably need to run \`solos setup\`."
    __profile__fn__error_press_enter
  fi
  git config --global user.name "$(cat "${gh_name_path}")" || __profile__fn__error_press_enter
  git config --global user.email "$(cat "${gh_email_path}")" || __profile__fn__error_press_enter
  if ! gh auth login --with-token <"${gh_token_path}"; then
    log_error "Github CLI failed to authenticate."
    __profile__fn__error_press_enter
  fi
  if ! gh auth setup-git; then
    log_error "Github CLI failed to setup."
    __profile__fn__error_press_enter
  fi
}

__profile__fn__install() {
  PS1='\[\033[0;32m\](SolOS:Debian)\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '
  if [[ -f "/etc/bash_completion" ]]; then
    . /etc/bash_completion
  else
    echo -e "\033[0;31mWARNING:\033[0m /etc/bash_completion not found. Bash completions will not be available."
  fi
  __profile__fn__install_gh
  __profile__fn__print_welcome_manual
  __profile__fn__bash_completions
  __profile__fn__run_checked_out_project_script
}
# Rename, export, and make readonly for all user-accessible pub functions.
# Ex: user should use `tag` rather than `__profile__fn__public_tag`.
__profile__fn__export_and_readonly() {
  __profile__pub_fns=""
  local pub_fns="$(declare -F | grep -o "__profile__fn__public_[a-z_]*" | xargs)"
  local internal_fns="$(compgen -A function | grep -o "__[a-z_]*__[a-z_]*" | xargs)"
  local internal_vars="$(compgen -v | grep -o "__[a-z_]*__[a-z_]*" | xargs)"
  for pub_func in ${pub_fns}; do
    pub_func_renamed="${pub_func#"__profile__fn__public_"}"
    eval "${pub_func_renamed}() { ${pub_func} \"\$@\"; }"
    eval "declare -g -r -f ${pub_func_renamed}"
    eval "export -f ${pub_func_renamed}"
    __profile__pub_fns="${pub_func_renamed} ${__profile__pub_fns}"
  done
}

# PUBLIC FUNCTIONS:

user_preexecs=()
user_postexecs=()

__profile__fn__public_reload() {
  if [[ ${1} == "--help" ]]; then
    cat <<EOF

USAGE: reload

DESCRIPTION:

Reload the current shell session.

EOF
    return 0
  fi
  trap - DEBUG
  trap - SIGINT
  if [[ -f "${HOME}/.solos/profile/.bashrc" ]]; then
    history -a
    bash --rcfile "${HOME}/.solos/profile/.bashrc" -i
  else
    log_info "No rcfile found at ${HOME}/.solos/profile/.bashrc. Skipping reload."
    trap 'exit 1;' SIGINT
    trap '__profile_tag__fn__trap' DEBUG
  fi
}
__profile__fn__public_tag() {
  __profile_tag__fn__main "$@"
}
__profile__fn__public_solos() {
  local executable_path="${HOME}/.solos/src/container/cli.sh"
  "${executable_path}" --restricted-shell "$@"
}
__profile__fn__public_info() {
  if [[ "${1}" == "--help" ]]; then
    cat <<EOF
USAGE: info

DESCRIPTION:

Print info about this shell.

EOF
    return 0
  fi
  echo ""
  __profile__fn__print_info
  echo ""
}
__profile__fn__public_preexec_list() {
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
__profile__fn__public_preexec_add() {
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
    log_error "preexec: missing function name"
    return 1
  fi
  if ! declare -f "${fn}" >/dev/null; then
    log_error "preexec: function '${fn}' not found"
    return 1
  fi
  if [[ " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
    log_error "preexec: function '${fn}' already exists in user_preexecs"
    return 1
  fi
  user_preexecs+=("${fn}")
}
__profile__fn__public_preexec_remove() {
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
    log_error "Invalid usage: preexec: function '${fn}' not found in user_preexecs"
    return 1
  fi
  user_preexecs=("${user_preexecs[@]/${fn}/}")
}
__profile__fn__public_postexec_list() {
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
__profile__fn__public_postexec_add() {
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
__profile__fn__public_postexec_remove() {
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
__profile__fn__public_install_solos() {
  __profile__fn__install
  __profile_tag__fn__install
}

__profile__fn__export_and_readonly
