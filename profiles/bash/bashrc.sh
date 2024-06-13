#!/usr/bin/env bash

# Skip command if we get an unsuccessful return code in the debug trap.
shopt -s extdebug
# When the shell exits, append to the history file instead of overwriting it.
shopt -s histappend
# Load this history file.
history -r

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/shared/log.sh" || exit 1
. "${HOME}/.solos/src/shared/gum.sh" || exit 1
. "${HOME}/.solos/src/profiles/bash/bashrc-panics.sh" || exit 1
. "${HOME}/.solos/src/profiles/bash/bashrc-table-outputs.sh" || exit 1
. "${HOME}/.solos/src/profiles/bash/bashrc-daemon.sh" || exit 1
. "${HOME}/.solos/src/profiles/bash/bashrc-user-execs.sh" || exit 1
. "${HOME}/.solos/src/profiles/bash/bashrc-track.sh" || exit 1

bashrc__pub_fns=""
bashrc__checked_out_project=""

if [[ ! ${PWD} =~ ^${HOME}/\.solos ]]; then
  cd "${HOME}/.solos" || exit 1
fi

bashrc.error_press_enter() {
  echo "Press enter to exit..."
  read -r || exit 1
  exit 1
}
bashrc.is_help_cmd() {
  if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]; then
    return 0
  else
    return 1
  fi
}
bashrc.users_home_dir() {
  local home_dir_path="$(lib.home_dir_path)"
  if [[ -z ${home_dir_path} ]]; then
    lib.panics_add "missing_home_dir" <<EOF
No reference to the user's home directory was found in the folder: ~/.solos/data/store.
EOF
    bashrc.error_press_enter
  fi
  echo "${home_dir_path}"
}
bashrc.extract_help_description() {
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
bashrc.bash_completions() {
  _custom_command_completions() {
    local cur prev words cword
    _init_completion || return
    _command_offset 1
  }
  complete -F _custom_command_completions track
  complete -F _custom_command_completions '-'
}
bashrc.run_checked_out_project_script() {
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
    bashrc.error_press_enter
  fi
  if [[ ${PWD} =~ ^${project_dir} ]]; then
    local project_script="${HOME}/.solos/projects/${checked_out_project}/solos.checkout.sh"
    if [[ -f ${project_script} ]]; then
      . "${project_script}"
      bashrc__checked_out_project="${checked_out_project}"
      echo -e "\033[0;32mChecked out project: ${bashrc__checked_out_project} \033[0m"
    fi
  fi
}
bashrc.print_info() {
  local checked_out_project="$(lib.checked_out_project)"
  local user_plugins_dir="${HOME}/.solos/plugins"
  local user_plugins=()
  if [[ -d ${user_plugins_dir} ]]; then
    while IFS= read -r user_plugin; do
      user_plugins+=("${user_plugin}")
    done < <(ls -1 "${user_plugins_dir}")
    if [[ ${#user_plugins[@]} -gt 0 ]]; then
      for user_plugin in "${user_plugins[@]}"; do
        user_plugins+=("${user_plugin}")
        local user_plugin_config_file="${user_plugins_dir}/${user_plugin}/solos.json"
        if [[ -f ${user_plugin_config_file} ]]; then
          user_plugins+=("${user_plugin_config_file}")
        fi
      done
    fi
  fi
  if [[ ${#user_plugins[@]} -eq 0 ]]; then
    local user_plugins_sections=""
  else
    local newline=$'\n'
    local user_plugins_sections="${newline}$(
      bashbashrc_table_outputs.format \
        "INSTALLED_PLUGIN,CONFIG_PATH" \
        "${user_plugins[@]}"
    )"
  fi
  cat <<EOF

$(
    bashbashrc_table_outputs.format \
      "SHELL_COMMAND,DESCRIPTION" \
      '-' "Runs its arguments as a command. Avoids pre/post exec functions and output tracking." \
      info "Print info about this shell." \
      ask_docs "$(ask_docs --help | bashrc.extract_help_description)" \
      track "$(track --help | bashrc.extract_help_description)" \
      solos "$(solos --help | bashrc.extract_help_description)" \
      preexec "$(preexec --help | bashrc.extract_help_description)" \
      postexec "$(postexec --help | bashrc.extract_help_description)" \
      daemon "$(daemon --help | bashrc.extract_help_description)" \
      reload "$(reload --help | bashrc.extract_help_description)" \
      panics "$(panics --help | bashrc.extract_help_description)"
  )

$(
    bashbashrc_table_outputs.format \
      "RESOURCE,PATH" \
      'Checked out project' "$(bashrc.users_home_dir)/.solos/projects/${checked_out_project}" \
      'User managed rcfile' "$(bashrc.users_home_dir)/.solos/rcfiles/.bashrc" \
      'Internal rcfile' "$(bashrc.users_home_dir)/.solos/src/profile/bashrc.sh" \
      'Config' "$(bashrc.users_home_dir)/.solos/config" \
      'Secrets' "$(bashrc.users_home_dir)/.solos/secrets" \
      'Data' "$(bashrc.users_home_dir)/.solos/data" \
      'Installed Plugins' "$(bashrc.users_home_dir)/.solos/plugins"
  )

$(
    bashbashrc_table_outputs.format \
      "SHELL_PROPERTY,VALUE" \
      "Shell" "BASH" \
      "Mounted Volume" "$(bashrc.users_home_dir)/.solos" \
      "Bash Version" "${BASH_VERSION}" \
      "Container OS" "Debian 12" \
      "SolOS Repo" "https://github.com/interbolt/solos"
  )
${user_plugins_sections}

$(
    bashbashrc_table_outputs.format \
      "LEGEND_KEY,LEGEND_DESCRIPTION" \
      "SHELL_COMMAND" "Commands available when sourcing the RC file at $(bashrc.users_home_dir)/.solos/rcfiles/.bashrc" \
      "RESOURCE" "Relevant directories and files managed by SolOS." \
      "SHELL_PROPERTY" "Properties that describe the SolOS environment." \
      "INSTALLED_PLUGIN" "Plugins available to all SolOS project."
  )
EOF
}
bashrc.print_welcome_manual() {
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
$(bashrc.print_info)

EOF
  local gh_status_line="$(gh auth status | grep "Logged in")"
  gh_status_line="${gh_status_line##*" "}"
  echo ""
  echo -e "\033[0;32mLogged in to Github ${gh_status_line} \033[0m"
  echo ""
}
bashrc.install_gh() {
  local secrets_path="${HOME}/.solos/secrets"
  local config_path="${HOME}/.solos/config"
  if [[ ! -d ${secrets_path} ]]; then
    log.error "No secrets directory found at ${secrets_path}. You probably need to run \`solos setup\`."
    bashrc.error_press_enter
  fi
  if [[ ! -d ${config_path} ]]; then
    log.error "No config directory found at ${config_path}. You probably need to run \`solos setup\`."
    bashrc.error_press_enter
  fi

  local gh_token_path="${secrets_path}/gh_token"
  local gh_name_path="${config_path}/gh_name"
  local gh_email_path="${config_path}/gh_email"
  if [[ ! -f ${gh_token_path} ]]; then
    log.error "No Github token found at ${gh_token_path}. You probably need to run \`solos setup\`."
    bashrc.error_press_enter
  fi
  if [[ ! -f ${gh_name_path} ]]; then
    log.error "No Github name found at ${gh_name_path}. You probably need to run \`solos setup\`."
    bashrc.error_press_enter
  fi
  if [[ ! -f ${gh_email_path} ]]; then
    log.error "No Github email found at ${gh_email_path}. You probably need to run \`solos setup\`."
    bashrc.error_press_enter
  fi
  git config --global user.name "$(cat "${gh_name_path}")" || bashrc.error_press_enter
  git config --global user.email "$(cat "${gh_email_path}")" || bashrc.error_press_enter
  if ! gh auth login --with-token <"${gh_token_path}"; then
    log.error "Github CLI failed to authenticate."
    bashrc.error_press_enter
  fi
  if ! gh auth setup-git; then
    log.error "Github CLI failed to setup."
    bashrc.error_press_enter
  fi
}
bashrc.install() {
  PS1='\[\033[0;32m\]SolOS\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '
  if [[ -f "/etc/bash_completion" ]]; then
    . /etc/bash_completion
  else
    echo -e "\033[0;31mWARNING:\033[0m /etc/bash_completion not found. Bash completions will not be available."
  fi
  bashrc.install_gh
  bashrc.print_welcome_manual
  bashrc.bash_completions
  bashrc.run_checked_out_project_script
}
# Rename, export, and make readonly for all user-accessible pub functions.
# Ex: user should use `tag` rather than `bashrc.public_track`.
bashrc.export_and_readonly() {
  bashrc__pub_fns=""
  local pub_fns="$(declare -F | grep -o "bashrc.public_[a-z_]*" | xargs)"
  local internal_fns="$(compgen -A function | grep -o "bashrc.[a-z_]*" | xargs)"
  local internal_vars="$(compgen -v | grep -o "bashrc__[a-z_]*" | xargs)"
  for pub_func in ${pub_fns}; do
    pub_func_renamed="${pub_func#"bashrc.public_"}"
    eval "${pub_func_renamed}() { ${pub_func} \"\$@\"; }"
    eval "declare -g -r -f ${pub_func_renamed}"
    eval "export -f ${pub_func_renamed}"
    bashrc__pub_fns="${pub_func_renamed} ${bashrc__pub_fns}"
  done
}

# PUBLIC FUNCTIONS:

user_preexecs=()
user_postexecs=()

bashrc.public_reload() {
  if bashrc.is_help_cmd "${1}"; then
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
    trap 'trap "bashbashrc_track.trap" DEBUG; exit 1;' SIGINT
    trap 'bashbashrc_track.trap' DEBUG
  fi
}
bashrc.public_ask_docs() {
  if bashrc.is_help_cmd "${1}"; then
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
bashrc.public_track() {
  bashbashrc_track.main "$@"
}
bashrc.public_solos() {
  local executable_path="${HOME}/.solos/src/cli/bin.sh"
  "${executable_path}" --restricted-shell "$@"
}
bashrc.public_info() {
  if bashrc.is_help_cmd "${1}"; then
    cat <<EOF
USAGE: info

DESCRIPTION:

Print info about this shell.

EOF
    return 0
  fi
  echo ""
  bashrc.print_info
  echo ""
}
bashrc.public_preexec() {
  bashrc_user_execs.main "pre" "$@"
}
bashrc.public_postexec() {
  bashrc_user_execs.main "post" "$@"
}
bashrc.public_daemon() {
  bashrc_daemon.main "$@"
}
bashrc.public_panics() {
  bashrc_panics.main "$@"
}
bashrc.public_install_solos() {
  bashrc_panics.install
  bashrc_daemon.install
  bashrc.install
  bashbashrc_track.install
  bashrc_user_execs.install
}
bashrc.export_and_readonly
