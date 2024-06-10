#!/usr/bin/env bash

# Skip command if we get an unsuccessful return code in the debug trap.
shopt -s extdebug
# When the shell exits, append to the history file instead of overwriting it.
shopt -s histappend
# Load this history file.
history -r

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
. "${HOME}/.solos/src/bash/log.sh" || exit 1
. "${HOME}/.solos/src/bash/gum.sh" || exit 1
. "${HOME}/.solos/src/bash/container/profile-panics.sh" || exit 1
. "${HOME}/.solos/src/bash/container/profile-table-outputs.sh" || exit 1
. "${HOME}/.solos/src/bash/container/profile-daemon.sh" || exit 1
. "${HOME}/.solos/src/bash/container/profile-user-execs.sh" || exit 1
. "${HOME}/.solos/src/bash/container/profile-track.sh" || exit 1

profile__pub_fns=""
profile__checked_out_project=""

if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
fi

profile.error_press_enter() {
  echo "Press enter to exit..."
  read -r || exit 1
  exit 1
}
profile.is_help_cmd() {
  if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]; then
    return 0
  else
    return 1
  fi
}
profile.users_home_dir() {
  local home_dir_path="$(lib.home_dir_path)"
  if [[ -z ${home_dir_path} ]]; then
    lib.panics_add "missing_home_dir" <<EOF
No reference to the user's home directory was found in the folder: ~/.solos/data/store.
EOF
    profile.error_press_enter
  fi
  echo "${home_dir_path}"
}
profile.extract_help_description() {
  local help_output=$(cat)
  if [[ -z ${help_output} ]]; then
    log.error "Unexpected error: empty help output."
    return 1
  fi
  local description_line_number=$(echo "${help_output}" | grep -n "^DESCRIPTION:" | cut -d: -f1)
  if [[ -z ${description_line_number} ]]; then
    log.error "Unexpected error: invalid help output format. Could not find a line starting with \`DESCRIPTION:\`"
    return 1
  fi
  local first_description_line=$((description_line_number + 2))
  if [[ -z $(echo "${help_output}" | sed -n "${first_description_line}p") ]]; then
    log.error "Unexpected error: invalid help output format. No text was found on the second line after DESCRIPTION:"
    return 1
  fi
  echo "${help_output}" | cut -d$'\n' -f"${first_description_line}"
}
profile.bash_completions() {
  _custom_command_completions() {
    local cur prev words cword
    _init_completion || return
    _command_offset 1
  }
  complete -F _custom_command_completions track
  complete -F _custom_command_completions '-'
}
profile.run_checked_out_project_script() {
  local checked_out_project="$(lib.checked_out_project)"
  if [[ -z ${checked_out_project} ]]; then
    return 0
  fi
  local projects_dir="${HOME}/.solos/projects"
  local project_dir="${projects_dir}/${checked_out_project}"
  if [[ ! ${PWD} =~ ^${project_dir} ]] && [[ ${PWD} != ${projects_dir} ]] && [[ ${PWD} =~ ^${projects_dir} ]]; then
    local pwd_project="$(basename "${PWD}")"
    echo "The checked out project does not match the project of your terminal's working directory." >&2
    echo "Run \`solos checkout ${pwd_project}\` in your host terminal to ensure VSCode can load the correct container when launching the SolOS shell." >&2
    profile.error_press_enter
  fi
  if [[ ${PWD} =~ ^${project_dir} ]]; then
    local project_script="${HOME}/.solos/projects/${checked_out_project}/solos.checkout.sh"
    if [[ -f ${project_script} ]]; then
      . "${project_script}"
      profile__checked_out_project="${checked_out_project}"
      echo -e "\033[0;32mChecked out project: ${profile__checked_out_project} \033[0m"
    fi
  fi
}
profile.print_info() {
  local checked_out_project="$(lib.checked_out_project)"
  local installed_plugins_dir="${HOME}/.solos/installed"
  local installed_plugins=()
  if [[ -d ${installed_plugins_dir} ]]; then
    while IFS= read -r installed_plugin; do
      installed_plugins+=("${installed_plugin}")
    done < <(ls -1 "${installed_plugins_dir}")
    if [[ ${#installed_plugins[@]} -gt 0 ]]; then
      for installed_plugin in "${installed_plugins[@]}"; do
        installed_plugins+=("${installed_plugin}" "${installed_plugins_dir}/${installed_plugin}/config.json")
      done
    fi
  fi
  if [[ ${#installed_plugins[@]} -eq 0 ]]; then
    local installed_plugins_sections=""
  else
    local newline=$'\n'
    local installed_plugins_sections="${newline}$(
      profile_table_outputs.format \
        "INSTALLED_PLUGIN,CONFIG_PATH" \
        "${installed_plugins[@]}"
    )"
  fi
  cat <<EOF

$(
    profile_table_outputs.format \
      "SHELL_COMMAND,DESCRIPTION" \
      '-' "Runs its arguments as a command. Avoids pre/post exec functions and output tracking." \
      info "Print info about this shell." \
      ask_docs "$(ask_docs --help | profile.extract_help_description)" \
      track "$(track --help | profile.extract_help_description)" \
      solos "$(solos --help | profile.extract_help_description)" \
      preexec "$(preexec --help | profile.extract_help_description)" \
      postexec "$(postexec --help | profile.extract_help_description)" \
      daemon "$(daemon --help | profile.extract_help_description)" \
      reload "$(reload --help | profile.extract_help_description)" \
      panics "$(panics --help | profile.extract_help_description)"
  )

$(
    profile_table_outputs.format \
      "RESOURCE,PATH" \
      'Checked out project' "$(profile.users_home_dir)/.solos/projects/${checked_out_project}" \
      'User managed rcfile' "$(profile.users_home_dir)/.solos/rcfiles/.bashrc" \
      'Internal rcfile' "$(profile.users_home_dir)/.solos/src/bash/container/profile.sh" \
      'Config' "$(profile.users_home_dir)/.solos/config" \
      'Secrets' "$(profile.users_home_dir)/.solos/secrets" \
      'Data' "$(profile.users_home_dir)/.solos/data" \
      'Installed Plugins' "$(profile.users_home_dir)/.solos/installed"
  )

$(
    profile_table_outputs.format \
      "SHELL_PROPERTY,VALUE" \
      "Shell" "BASH" \
      "Mounted Volume" "$(profile.users_home_dir)/.solos" \
      "Bash Version" "${BASH_VERSION}" \
      "Container OS" "Debian 12" \
      "SolOS Repo" "https://github.com/interbolt/solos"
  )
${installed_plugins_sections}

$(
    profile_table_outputs.format \
      "LEGEND_KEY,LEGEND_DESCRIPTION" \
      "SHELL_COMMAND" "Commands available when sourcing ~/.solos/src/bash/container/profile.sh." \
      "RESOURCE" "Relevant directories and files managed by SolOS." \
      "SHELL_PROPERTY" "Properties that describe the SolOS environment." \
      "INSTALLED_PLUGIN" "Plugins available to all SolOS project."
  )
EOF
}
profile.print_welcome_manual() {
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
$(profile.print_info)

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo ""
  echo -e "\033[0;32mLogged in to Github ${gh_status_line} \033[0m"
  echo ""
}
profile.install_gh() {
  local secrets_path="${HOME}/.solos/secrets"
  local config_path="${HOME}/.solos/config"
  if [[ ! -d ${secrets_path} ]]; then
    log.error "No secrets directory found at ${secrets_path}. You probably need to run \`solos setup\`."
    profile.error_press_enter
  fi
  if [[ ! -d ${config_path} ]]; then
    log.error "No config directory found at ${config_path}. You probably need to run \`solos setup\`."
    profile.error_press_enter
  fi

  local gh_token_path="${secrets_path}/gh_token"
  local gh_name_path="${config_path}/gh_name"
  local gh_email_path="${config_path}/gh_email"
  if [[ ! -f ${gh_token_path} ]]; then
    log.error "No Github token found at ${gh_token_path}. You probably need to run \`solos setup\`."
    profile.error_press_enter
  fi
  if [[ ! -f ${gh_name_path} ]]; then
    log.error "No Github name found at ${gh_name_path}. You probably need to run \`solos setup\`."
    profile.error_press_enter
  fi
  if [[ ! -f ${gh_email_path} ]]; then
    log.error "No Github email found at ${gh_email_path}. You probably need to run \`solos setup\`."
    profile.error_press_enter
  fi
  git config --global user.name "$(cat "${gh_name_path}")" || profile.error_press_enter
  git config --global user.email "$(cat "${gh_email_path}")" || profile.error_press_enter
  if ! gh auth login --with-token <"${gh_token_path}"; then
    log.error "Github CLI failed to authenticate."
    profile.error_press_enter
  fi
  if ! gh auth setup-git; then
    log.error "Github CLI failed to setup."
    profile.error_press_enter
  fi
}
profile.install() {
  PS1='\[\033[0;32m\]SolOS\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '
  if [[ -f "/etc/bash_completion" ]]; then
    . /etc/bash_completion
  else
    echo -e "\033[0;31mWARNING:\033[0m /etc/bash_completion not found. Bash completions will not be available."
  fi
  profile.install_gh
  profile.print_welcome_manual
  profile.bash_completions
  profile.run_checked_out_project_script
}
# Rename, export, and make readonly for all user-accessible pub functions.
# Ex: user should use `tag` rather than `profile.public_track`.
profile.export_and_readonly() {
  profile__pub_fns=""
  local pub_fns="$(declare -F | grep -o "profile.public_[a-z_]*" | xargs)"
  local internal_fns="$(compgen -A function | grep -o "profile.[a-z_]*" | xargs)"
  local internal_vars="$(compgen -v | grep -o "profile__[a-z_]*" | xargs)"
  for pub_func in ${pub_fns}; do
    pub_func_renamed="${pub_func#"profile.public_"}"
    eval "${pub_func_renamed}() { ${pub_func} \"\$@\"; }"
    eval "declare -g -r -f ${pub_func_renamed}"
    eval "export -f ${pub_func_renamed}"
    profile__pub_fns="${pub_func_renamed} ${profile__pub_fns}"
  done
}

# PUBLIC FUNCTIONS:

user_preexecs=()
user_postexecs=()

profile.public_reload() {
  if profile.is_help_cmd "${1}"; then
    cat <<EOF

USAGE: reload

DESCRIPTION:

Reload the current shell session. Warning: exiting a reloaded shell will take you back \
to the version of the shell before the reload. \
So you might need to type \`exit\` a few times to completely exit the shell.

EOF
    return 0
  fi
  trap - DEBUG
  trap - SIGINT
  if [[ -f "${HOME}/.solos/rcfiles/.bashrc" ]]; then
    history -a
    bash --rcfile "${HOME}/.solos/rcfiles/.bashrc" -i
  else
    log.info "No rcfile found at ${HOME}/.solos/rcfiles/.bashrc. Skipping reload."
    trap 'trap "profile_track.trap" DEBUG; exit 1;' SIGINT
    trap 'profile_track.trap' DEBUG
  fi
}
profile.public_ask_docs() {
  if profile.is_help_cmd "${1}"; then
    cat <<EOF
USAGE: ask_docs <question>

DESCRIPTION:

Ask a question about the SolOS documentation.

EOF
    return 0
  fi
  local query=''"${*}"''
  if [[ -z ${query} ]]; then
    log.error "No question provided."
    return 1
  fi
  if [[ ! -f ${HOME}/.solos/secrets/openai_api_key ]]; then
    log.error "This feature is disabled since you did not provide SolOS with an OpenAI API key during the setup process. Use \`solos setup\` to add one."
    return 1
  fi
  log.warn "TODO: No implementation exists yet. Stay tuned."
}
profile.public_track() {
  profile_track.main "$@"
}
profile.public_solos() {
  local executable_path="${HOME}/.solos/src/bash/container/cli.sh"
  "${executable_path}" --restricted-shell "$@"
}
profile.public_info() {
  if profile.is_help_cmd "${1}"; then
    cat <<EOF
USAGE: info

DESCRIPTION:

Print info about this shell.

EOF
    return 0
  fi
  echo ""
  profile.print_info
  echo ""
}
profile.public_preexec() {
  profile_user_execs.main "pre" "$@"
}
profile.public_postexec() {
  profile_user_execs.main "post" "$@"
}
profile.public_daemon() {
  profile_daemon.main "$@"
}
profile.public_panics() {
  profile_panics.main "$@"
}
profile.public_install_solos() {
  profile_panics.install
  profile_daemon.install
  profile.install
  profile_track.install
  profile_user_execs.install
}
profile.export_and_readonly
