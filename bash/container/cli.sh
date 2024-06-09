#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1
#                                     /\             /\
#                                    |`\\_,--="=--,_//`|
#                                    \ ."  :'. .':  ". /
#                                   ==)  _ :  '  : _  (==
#                                     |>/O\   _   /O\<|
#                                     | \-"~` _ `~"-/ |   jgs
#                                    >|`===. \_/ .===`|<
#                              .-"-.   \==='  |  '===/   .-"-.
# .---------------------------{'. '`}---\,  .-'-.  ,/---{.'. '}---------------------------.
#  )                          `"---"`     `~-===-~`     `"---"`                          (
# (  Welcome to the SolOS CLI.                                                            )
#  ) This script is intended to run in a Debian 12 docker container.                     (
# (  It is not POSIX compliant and must be run with Bash version >= 5.0                   )
#  )                                                                                     (
# '---------------------------------------------------------------------------------------'
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
shopt -s dotglob
set -o errexit
#-------------------------------------------------------------------------------------------
#
# RESTRICTED FLAGS:
# The prefix --restricted-* is kind of dumb but it's specific to internal uses of the CLI
# which means we can change it at anytime without worrying about breaking changes.
#
# --restricted-noop
#     - Exits with 0 - serves only to confirm that the script is executable post-installation.
#       Look, I'd love to assume that yeah, it'll work, we're just writing a little
#       bash, running a little docker, executing some commands...
# --restricted-shell
#     - Detects whether or not the script was invoked from within the SolOS shell.
#       Example use case - prevent checking out a different project within the shell
#       since our shell assumes a consistent project context for its entire lifetime.
#       Could we engineer this away? Sure. But is it simpler to support a rich feature set
#       within the SolOS shell if we can always assume a consistent project context?
#       Also, sure.
#
#-------------------------------------------------------------------------------------------
for arg in "$@"; do
  if [[ ${arg} = "--restricted-noop" ]]; then
    exit 0
  fi
done
cli__is_running_in_shell=false
for arg in "$@"; do
  if [[ ${arg} = "--restricted-shell" ]]; then
    cli__is_running_in_shell=true
  fi
done
cli__restricted_args=()
while [[ $# -gt 0 ]]; do
  if [[ ${1} != --restricted-* ]]; then
    cli__restricted_args+=("${1}")
  fi
  shift
done
set -- "${cli__restricted_args[@]}"
#--------------------------------------------------------------------
# LIB:GLOBAL: Stuff that everything across all SolOS projects needs.
#--------------------------------------------------------------------
cli.global_store.del() {
  local store_dir="${HOME}/.solos/data/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}
cli.global_store.get() {
  local store_dir="${HOME}/.solos/data/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}
cli.global_store.set() {
  local store_dir="${HOME}/.solos/data/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}
#-------------------------------------------------------------------
# cli__users_home_dir: The user's home directory on their host machine
# cli__cmd: The command to run. Populated in the argparse functions.
# cli__allowed_options: An array of the allowed options for the current command.
# cli__options: An array of the options passed to the CLI.
# cli__project_name: The name of the project being worked on.
# cli__project_app: The name of the app within the project being worked on.
#-------------------------------------------------------------------
cli__restricted_args=()
for arg in "$@"; do
  if [[ ${arg} != --restricted-* ]]; then
    cli__restricted_args+=("${arg}")
  fi
done
cli__users_home_dir="$(cli.global_store.get "users_home_dir" "/root")"
cli__cmd=""
cli__allowed_options=()
cli__options=()
cli__project_name=""
cli__project_app=""
#-------------------------------------------------------------------
# Source any dependencies that are required for the CLI to function.
# These are placed below the definition of cli__users_home_dir because
# they might rely on it.
#-------------------------------------------------------------------
. "${HOME}/.solos/src/bash/gum.sh"
. "${HOME}/.solos/src/bash/log.sh"
#-------------------------------------------------
# LIB:USAGE: CLI Help Information
#-------------------------------------------------
cli.usage.cmds.help() {
  cat <<EOF
USAGE: solos <command> <args..>

DESCRIPTION:

Manage your SolOS projects and apps.

COMMANDS:

checkout                 - Switch to a pre-existing project or initialize a new one.
app                      - Initializes or checks out a project app.
shell                    - Start a SolOS shell session with ~/.solos/rcfiles/.bashrc sourced.
shell-minimal            - Start a SolOS shell session without sourcing ~/.solos/rcfiles/.bashrc.
setup                    - Configure SolOS for things like Git credentials, API keys, etc.

Source: https://github.com/InterBolt/solos
EOF
}
cli.usage.checkout.help() {
  cat <<EOF
USAGE: solos checkout <project>

DESCRIPTION:

Creates a new project if one doesn't exist and then switches to it. The project name \
is cached in the CLI so that all future commands operate against it. Think git checkout.

EOF
}
cli.usage.app.help() {
  cat <<EOF
USAGE: solos app <app_name>

DESCRIPTION:

Initialize a new app within a project if the app doesn't already exist. If it does, \
it will checkout and re-install env dependencies for the app.

EOF
}
cli.usage.shell.help() {
  cat <<EOF
USAGE: solos shell

DESCRIPTION:

Loads a interactive bash shell with the RC file at ~/.solos/rcfiles/.bashrc sourced.

EOF
}
cli.usage.shell_minimal.help() {
  cat <<EOF
USAGE: solos shell-minimal

DESCRIPTION:

Loads a interactive bash shell without a RC file.

EOF
}
cli.usage.setup.help() {
  cat <<EOF
USAGE: solos setup

DESCRIPTION:

Configure SolOS for things like Git credentials, API keys, etc.

EOF
}
#------------------------------------------------------------
# LIB:ARGPARSE: Converts arguments into usable variables
#------------------------------------------------------------
cli.argparse._is_valid_help_command() {
  if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]; then
    return 0
  else
    return 1
  fi
}
cli.argparse._allowed_cmds() {
  local allowed_cmds=()
  for cmd in $(compgen -A function | grep "cli.usage.*.help"); do
    local cmd_name=$(echo "${cmd}" | awk -F '.' '{print $3}' | tr '_' '-')
    if [[ ${cmd_name} != "cmds" ]]; then
      allowed_cmds+=("${cmd_name}")
    fi
  done
  echo "${allowed_cmds[@]}"
}
cli.argparse.cmd() {
  local allowed_cmds=($(cli.argparse._allowed_cmds))
  if [[ -z "$1" ]]; then
    log.error "No command supplied."
    cli.usage.cmds.help
    exit 0
  fi
  if cli.argparse._is_valid_help_command "$1"; then
    cli.usage.cmds.help
    exit 0
  fi
  local post_command_arg_index=0
  while [[ "$#" -gt 0 ]]; do
    if cli.argparse._is_valid_help_command "$1"; then
      if [[ -z ${cli__cmd} ]]; then
        log.error "invalid command, use \`solos --help\` to see available commands."
        exit 1
      fi
      cli.usage."${cli__cmd}".help
      exit 0
    fi
    case "$1" in
    --*)
      local key=$(echo "$1" | awk -F '=' '{print $1}' | sed 's/^--//')
      local value=$(echo "$1" | awk -F '=' '{print $2}')
      cli__options+=("${key}=${value}")
      ;;
    *)
      if [[ -z "$1" ]]; then
        break
      fi
      if [[ -n "${cli__cmd}" ]]; then
        post_command_arg_index=$((post_command_arg_index + 1))
        cli__options+=("argv${post_command_arg_index}=$1")
        break
      fi
      local cmd_name=$(echo "$1" | tr '-' '_')
      local is_allowed=false
      for allowed_cmd_name in "${allowed_cmds[@]}"; do
        if [[ ${cmd_name} = "${allowed_cmd_name}" ]]; then
          is_allowed=true
        fi
      done
      if [[ ${is_allowed} = "false" ]]; then
        log.error "Unknown command: $1"
      else
        cli__cmd="${cmd_name}"
      fi
      ;;
    esac
    shift
  done
}
cli.argparse.requirements() {
  local allowed_cmds=($(cli.argparse._allowed_cmds))
  for cmd_name in $(
    cli.usage.cmds.help |
      grep -A 1000 "COMMANDS:" |
      grep -v "COMMANDS:" |
      grep -E "^[a-z]" |
      awk '{print $1}'
  ); do
    cmd_name=$(echo "${cmd_name}" | tr '-' '_')
    if [[ "${cmd_name}" != "help" ]]; then
      allowed_cmds+=("${cmd_name}")
    fi
  done
  for cmd in "${allowed_cmds[@]}"; do
    cmd="$(echo "${cmd}" | tr '-' '_')"
    opts="${cmd}("
    first=true
    for cmd_option in $(cli.usage."${cmd}".help | grep -E "^--" | awk '{print $1}'); do
      cmd_option="$(echo "${cmd_option}" | awk -F '=' '{print $1}' | sed 's/^--//')"
      if [[ ${first} = true ]]; then
        opts="${opts}${cmd_option}"
      else
        opts="${opts},${cmd_option}"
      fi
      first=false
    done
    cli__allowed_options+=("${opts})")
  done
}
cli.argparse.validate_opts() {
  if [[ -n ${cli__options[0]} ]]; then
    for cmd_option in "${cli__options[@]}"; do
      for allowed_cmd_option in "${cli__allowed_options[@]}"; do
        cmd_name=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $1}')
        cmd_options=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
        if [[ ${cmd_name} = "${cli__cmd}" ]]; then
          is_cmd_option_allowed=false
          flag_name="$(echo "${cmd_option}" | awk -F '=' '{print $1}')"
          for cmd_option in "$(echo "${cmd_options}" | tr ',' '\n')"; do
            if [[ ${cmd_option} = "${flag_name}" ]]; then
              is_cmd_option_allowed=true
            fi
          done
          if [[ ${flag_name} = "argv"* ]]; then
            is_cmd_option_allowed=true
          fi
          if [[ ${is_cmd_option_allowed} = false ]]; then
            echo ""
            echo "Command option: ${cmd_option} is not allowed for command: ${cli__cmd}."
            echo ""
            exit 1
          fi
        fi
      done
    done
  fi
}
cli.argparse.ingest() {
  local checked_out_project="$(cli.global_store.get "checked_out_project")"
  if [[ ${cli__cmd} = "checkout" ]] && [[ ${#cli__options[@]} -eq 0 ]]; then
    if [[ -z ${checked_out_project} ]]; then
      log.error "No project currently checked out."
      return 1
    fi
    cli__options=("argv1=${checked_out_project}")
  fi
  for i in "${!cli__options[@]}"; do
    case "${cli__options[$i]}" in
    argv1=*)
      if [[ ${cli__cmd} = "app" ]]; then
        cli__project_app="${cli__options[$i]#*=}"
      fi
      if [[ ${cli__cmd} = "checkout" ]]; then
        cli__project_name="${cli__options[$i]#*=}"
        # If we're running from the SolOS shell, prevent checking out a different cli.project.
        # This is not the best solution but one that will prevent hair-pulling bugs/inconsistencies
        # while we work on a better solution.
        if [[ ${cli__is_running_in_shell} = true ]]; then
          if [[ -n ${cli__project_name} ]] && [[ ${checked_out_project} != "${cli__project_name}" ]]; then
            log.error \
              "Usage error: \`solos checkout ${cli__project_name}\` must be run on your host machine."
            return 1
          fi
          if [[ -n ${checked_out_project} ]]; then
            cli__project_name="${checked_out_project}"
          fi
        fi
      fi
      ;;
    esac
  done
}
#-------------------------------------------------------------
# LIB:CONFIG_STORE: Amy strings we don't need to keep secret,
#                   but will likely reference, change, and use
#                   across projects.
#-------------------------------------------------------------
cli.config_store.del() {
  local store_dir="${HOME}/.solos/config"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}
cli.config_store.get() {
  local store_dir="${HOME}/.solos/config"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}
cli.config_store.set() {
  local store_dir="${HOME}/.solos/config"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}
#-----------------------------------------------------------------
# LIB:PROJECT_STORE: Things about a project that could be public.
#-----------------------------------------------------------------
cli.project_store.del() {
  if [[ -z ${cli__project_name} ]]; then
    log.error "cli__project_name is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${cli__project_name} ]]; then
    log.error "Project not found: ${cli__project_name}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${cli__project_name}/data/store"
  if [[ -z $1 ]]; then
    log.warn "No key provided. Nothing to delete."
    return 0
  fi
  rm -f "${project_store_dir}/$1"
}
cli.project_store.get() {
  if [[ -z ${cli__project_name} ]]; then
    log.error "cli__project_name is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${cli__project_name} ]]; then
    log.error "Project not found: ${cli__project_name}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${cli__project_name}/data/store"
  local project_store_file="${project_store_dir}/$1"
  if [[ -f ${project_store_file} ]]; then
    cat "${project_store_file}"
  else
    echo ""
  fi
}
cli.project_store.set() {
  if [[ -z ${cli__project_name} ]]; then
    log.error "cli__project_name is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${cli__project_name} ]]; then
    log.error "Project not found: ${cli__project_name}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${cli__project_name}/data/store"
  if [[ -z $1 ]]; then
    log.warn "No key provided. Nothing to set."
    return 0
  fi
  local project_store_file="${project_store_dir}/$1"
  if [[ ! -f ${project_store_file} ]]; then
    touch "${project_store_file}"
  fi
  echo "$2" >"${project_store_file}"
}
#-------------------------------------------------
# LIB:PROJECT_SECRETS: Per-project secrets
#-------------------------------------------------
cli.secrets_store.del() {
  local store_dir="${HOME}/.solos/secrets"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}
cli.secrets_store.get() {
  local store_dir="${HOME}/.solos/secrets"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}
cli.secrets_store.set() {
  local store_dir="${HOME}/.solos/secrets"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}
#-------------------------------------------------
# LIB:SSH: SSH stuff. Just creating keys for now.
#-------------------------------------------------
cli.ssh.create() {
  local key_name="$1"
  local ssh_dir="${2}"
  mkdir -p "${ssh_dir}"
  local privkey_path="${ssh_dir}/${key_name}.priv"
  local pubkey_path="${ssh_dir}/${key_name}.pub"
  if [[ -z ${key_name} ]]; then
    log.error "key_name is required."
    exit 1
  fi
  if [[ -f ${privkey_path} ]]; then
    log.error "key file already exists: ${privkey_path}"
    exit 1
  fi
  if [[ -f ${pubkey_path} ]]; then
    log.error "key file already exists: ${pubkey_path}"
    exit 1
  fi
  local entry_dir="${PWD}"
  cd "${ssh_dir}" || exit 1
  if ! ssh-keygen -t rsa -q -f "${privkey_path}" -N "" >/dev/null; then
    log.error "Could not create SSH keypair."
    exit 1
  else
    mv "${privkey_path}.pub" "${pubkey_path}"
    chmod 644 "${pubkey_path}"
    chmod 600 "${privkey_path}"
  fi
  cd "${entry_dir}" || exit 1
}
#----------------------------------------------
# LIB:UTILS: Anything and everything, brother.
#----------------------------------------------
cli.utils.template_variables() {
  local dir_or_file="$1"
  local eligible_files=()
  if [[ -d ${dir_or_file} ]]; then
    for file in "${dir_or_file}"/*; do
      if [[ -d ${file} ]]; then
        cli.utils.template_variables "${file}"
      fi
      if [[ -f ${file} ]]; then
        eligible_files+=("${file}")
      fi
    done
  elif [[ -f ${dir_or_file} ]]; then
    eligible_files+=("${dir_or_file}")
  fi
  if [[ ${#eligible_files[@]} -eq 0 ]]; then
    return
  fi
  local errored=false
  for file in "${eligible_files[@]}"; do
    bin_vars=$(grep -o "___cli__[a-z0-9_]*___" "${file}" | sed 's/___//g')
    for bin_var in ${bin_vars}; do
      if [[ -z ${!bin_var+x} ]]; then
        log.error "Template variables error: ${file} is using an unset variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ -z ${!bin_var} ]]; then
        log.error "Template variables error: ${file} is using an empty variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ ${errored} = "false" ]]; then
        sed -i "s,___${bin_var}___,${!bin_var},g" "${file}"
      fi
    done
  done
  if [[ ${errored} = "true" ]]; then
    exit 1
  fi
}
cli.utils.git_hash() {
  local source_code_path="${HOME}/.solos/src"
  if [[ ! -d "${source_code_path}" ]]; then
    log.error "Unexpected error: nothing found at ${source_code_path}. Cannot generate a version hash."
    exit 1
  fi
  git -C "${source_code_path}" rev-parse --short HEAD | cut -c1-7 || echo ""
}
cli.utils.pretty_print_dir_files() {
  local dir="$1"
  local tilde_dir="${dir/#\/root/\~}"
  for store_dir_file in "${dir}"/*; do
    local filename="$(basename ${store_dir_file})"
    printf "\033[0;32m%s\033[0m\n" "${tilde_dir}/${filename}: $(cat ${store_dir_file})"
  done
}
#----------------------------------------------------------------------------
# LIB:CMD: CLI command implementations and their specific helper functions.
#          at cmd.<command_name>_<subcommand_name>.
#----------------------------------------------------------------------------
cli.cmd.app._remove_app_from_code_workspace() {
  local workspace_file="$1"
  jq 'del(.folders[] | select(.name == "'"${cli__project_name}"'.'"${cli__project_app}"'"))' "${workspace_file}" >"${workspace_file}.tmp"
  if ! jq . "${workspace_file}.tmp" >/dev/null; then
    log.error "Failed to validate the updated code workspace file: ${workspace_file}.tmp"
    exit 1
  fi
  mv "${workspace_file}.tmp" "${workspace_file}"
}
cli.cmd.app._get_path_to_app() {
  local path_to_apps="${HOME}/.solos/projects/${cli__project_name}/apps"
  mkdir -p "${path_to_apps}"
  echo "${path_to_apps}/${cli__project_app}"
}
cli.cmd.app._init() {
  if [[ ! ${cli__project_app} =~ ^[a-z_-]*$ ]]; then
    log.error "Invalid app name. App names must be lowercase and can only contain letters, hyphens, and underscores."
    exit 1
  fi
  # Do this to prevent when the case where the user wants to create an app but has the wrong
  # project checked out. They can still fuck it up but at least we provide some guardrail.
  local should_continue="$(gum.confirm_new_app "${cli__project_name}" "${cli__project_app}")"
  if [[ ${should_continue} = false ]]; then
    log.error "${cli__project_name}:${cli__project_app} - Aborted."
    exit 1
  fi
  local tmp_app_dir="$(mktemp -d -q)"
  local tmp_misc_dir="$(mktemp -d -q)"
  local tmp_file="$(mktemp -d -q)/repo"
  if ! gum.repo_url >"${tmp_file}"; then
    log.error "${cli__project_name}:${cli__project_app} - Aborted."
    exit 1
  fi
  local repo_url="$(cat "${tmp_file}")"
  if [[ -n ${repo_url} ]]; then
    if ! git clone "$(cat ${tmp_file})" "${tmp_app_dir}" >/dev/null; then
      log.error "Failed to clone the app's repository."
      exit 1
    fi
    log.info "${cli__project_name}:${cli__project_app} - Cloned the app's repository."
  else
    log.warn "${cli__project_name}:${cli__project_app} - No repo url supplied. Creating an empty app directory."
  fi
  cat <<EOF >"${tmp_app_dir}/solos.preexec.sh"
#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

#########################################################################################################
## This script is executed prior to any command run in the SolOS's shell when the working directory is a 
## the parent directory or a subdirectory of the app's directory. The output of this script is not
## included in your command's stdout/err but is visible in the terminal.
## Do things like check for dependencies, set environment variables, etc.
##
## Example logic: if an app requires a specific version of Node.js, you could check for it here 
## and then use nvm to switch to it.
##
## Important note: Idempotency is YOUR responsibility.
#########################################################################################################

# Write your code below:
echo "Hello from the pre-exec script for app: ${cli__project_app}"
EOF
  cat <<EOF >"${tmp_app_dir}/solos.postexec.sh"
#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

#########################################################################################################
## This script is executed after any command run in the SolOS's shell when the working directory is a 
## the parent directory or a subdirectory of the app's directory. The output of this script is not
## included in your command's stdout/err but is visible in the terminal.
##
## Important note: Idempotency is YOUR responsibility.
#########################################################################################################

# Write your code below:
echo "Hello from the post-exec script for app: ${cli__project_app}"
EOF
  log.info "${cli__project_name}:${cli__project_app} - Created the pre-exec script."
  local app_dir="$(cli.cmd.app._get_path_to_app)"
  local vscode_workspace_file="${HOME}/.solos/projects/${cli__project_name}/.vscode/solos-${cli__project_name}.code-workspace"
  local tmp_vscode_workspace_file="${tmp_misc_dir}/$(basename ${vscode_workspace_file})"
  if [[ ! -f "${vscode_workspace_file}" ]]; then
    log.error "Unexpected error: no code workspace file: ${vscode_workspace_file}"
    exit 1
  fi
  cp -f "${vscode_workspace_file}" "${tmp_vscode_workspace_file}"
  # The goal is to remove the app and then add it back to the beginning of the folders array.
  # This gives the best UX in VS Code since a new terminal will automatically assume the app's dir context.
  cli.cmd.app._remove_app_from_code_workspace "${tmp_vscode_workspace_file}"
  jq \
    --arg app_name "${cli__project_app}" \
    '.folders |= [{ "name": "app.'"${cli__project_app}"'", "uri": "'"${cli__users_home_dir}"'/.solos/projects/'"${cli__project_name}"'/apps/'"${cli__project_app}"'", "profile": "shell" }] + .' \
    "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
  mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
  if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
    log.error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
    exit 1
  fi

  chmod +x "${tmp_app_dir}/solos.preexec.sh"
  chmod +x "${tmp_app_dir}/solos.postexec.sh"
  log.info "${cli__project_name}:${cli__project_app} - Made the lifecycle scripts executable."

  # Do last to prevent partial app setup.
  mv "${tmp_app_dir}" "${app_dir}"
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  rm -rf "${tmp_misc_dir}"
  log.info "${cli__project_name}:${cli__project_app} - Initialized the app."
}
cli.cmd.app() {
  cli__project_name="$(cli.global_store.get "checked_out_project")"
  if [[ -z ${cli__project_name} ]]; then
    log.error "No project currently checked out."
    exit 1
  fi
  if [[ -z "${cli__project_app}" ]]; then
    log.error "No app name was supplied."
    exit 1
  fi
  if [[ -z "${cli__project_name}" ]]; then
    log.error "A project name is required. Please checkout a project first."
    exit 1
  fi
  local app_dir="$(cli.cmd.app._get_path_to_app)"
  if [[ ! -d ${app_dir} ]]; then
    cli.cmd.app._init
  else
    log.info "${cli__project_name}:${cli__project_app} - App already exists."
  fi
}
cli.cmd.checkout() {
  if [[ -z ${cli__project_name} ]]; then
    log.error "No project name was supplied."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects ]]; then
    mkdir -p "${HOME}/.solos/projects"
    log.info "No projects found. Creating ~/.solos/projects directory."
  fi
  # If the project dir exists, let's assume it was setup ok.
  # We'll use a tmp dir to build up the files so that unexpected errors
  # won't result in a partial project dir.
  if [[ ! -d ${HOME}/.solos/projects/${cli__project_name} ]]; then
    local tmp_project_ssh_dir="$(mktemp -d -q)"
    if [[ ! -d ${tmp_project_ssh_dir} ]]; then
      log.error "Unexpected error: no tmp dir was created."
      exit 1
    fi
    cli.ssh.create "default" "${tmp_project_ssh_dir}" || exit 1
    log.info "${cli__project_name} - Created keypair for project"
    mkdir -p "${HOME}/.solos/projects/${cli__project_name}"
    mkdir -p "${HOME}/.solos/projects/${cli__project_name}/data/store"
    echo "# Any plugin names listed below this line will be turned off when working in this project." \
      >"${HOME}/.solos/projects/${cli__project_name}/solos.ignoreplugins"
    cp -a "${tmp_project_ssh_dir}" "${HOME}/.solos/projects/${cli__project_name}/.ssh"
    log.info "${cli__project_name} - Established project directory"
    local vscode_dir="${HOME}/.solos/projects/${cli__project_name}/.vscode"
    mkdir -p "${vscode_dir}"
    local tmp_dir="$(mktemp -d -q)"
    cp "${HOME}/.solos/src/solos.code-workspace" "${tmp_dir}/solos-${cli__project_name}.code-workspace"
    if cli.utils.template_variables "${tmp_dir}/solos-${cli__project_name}.code-workspace"; then
      cp -f "${tmp_dir}/solos-${cli__project_name}.code-workspace" "${vscode_dir}/solos-${cli__project_name}.code-workspace"
      log.info "${cli__project_name} - Successfully templated the Visual Studio Code workspace file."
    else
      log.error "${cli__project_name} - Failed to build the code workspace file."
      exit 1
    fi

    local checkout_script="${HOME}/.solos/projects/${cli__project_name}/solos.checkout.sh"
    if [[ -f ${checkout_script} ]]; then
      chmod +x "${checkout_script}"
      if ! "${checkout_script}"; then
        log.warn "${cli__project_name} - Failed to run the checkout script."
      else
        log.info "${cli__project_name} - Checkout out."
      fi
    else
      cat <<EOF >"${checkout_script}"
#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

######################################################################################################################
## This script runs at two different possible points in time:
## 1) When the \`solos checkout\` command is run from your host machine (checkout is not allowed in the SolOS shell).
## 2) When the shell launches and a project is checked out.

# We can't guarantee that it only runs when the container is initialized but we can safely assume it will never run
# in another project's container.
######################################################################################################################

# Write your code below:
echo "Hello from the checkout script for project: ${cli__project_name}"

EOF
      chmod +x "${checkout_script}"
      log.info "${cli__project_name} - Created the checkout script."
    fi
  fi
  cli.global_store.set "checked_out_project" "${cli__project_name}"
}
cli.cmd.setup._print_curr_setup() {
  local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
  echo ""
  echo "${full_line}"
  echo ""
  echo "CURRENT SETUP:"
  echo ""
  cli.utils.pretty_print_dir_files "${HOME}/.solos/config"
  cli.utils.pretty_print_dir_files "${HOME}/.solos/secrets"
  echo ""
  echo "${full_line}"
}
cli.cmd.setup._gh_token() {
  local tmp_file="$1"
  local gh_token="$(gum.github_token)"
  if [[ -z ${gh_token} ]]; then
    exit 1
  fi
  echo "${gh_token}" >"${tmp_file}"
  if gh auth login --with-token <"${tmp_file}" >/dev/null; then
    log.info "Updated Github token."
  else
    log.error "Failed to authenticate with: ${gh_token}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      cli.cmd.setup._gh_token "${tmp_file}"
    else
      log.error "Exiting the setup process."
      exit 1
    fi
  fi
}
cli.cmd.setup._gh_email() {
  local tmp_file="$1"
  local github_email="$(gum.github_email)"
  if [[ -z ${github_email} ]]; then
    exit 1
  fi
  echo "${github_email}" >"${tmp_file}"
  if git config --global user.email "${github_email}"; then
    log.info "Updated git email."
  else
    log.error "Failed to update git user.email to: ${github_email}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      cli.cmd.setup._gh_token "${tmp_file}"
    else
      log.error "Exiting the setup process."
      exit 1
    fi
  fi
}
cli.cmd.setup._gh_name() {
  local tmp_file="$1"
  local github_name="$(gum.github_name)"
  if [[ -z ${github_name} ]]; then
    exit 1
  fi
  echo "${github_name}" >"${tmp_file}"
  if git config --global user.name "${github_name}"; then
    log.info "Updated git name."
  else
    log.error "Failed to update git user.name to: ${github_name}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      cli.cmd.setup._gh_token "${tmp_file}"
    else
      log.error "Exiting the setup process."
      exit 1
    fi
  fi
}
cli.cmd.setup._openai_api_key() {
  local tmp_file="$1"
  gum.optional_openai_api_key_input >"${tmp_file}" || exit 1
  local openai_api_key=$(cat "${tmp_file}" 2>/dev/null || echo "")
  if [[ -z ${openai_api_key} ]]; then
    log.warn "Local AI features will be turned off."
    return 0
  fi
  if curl -s -o /dev/null -w "%{http_code}" https://api.openai.com/v1/models -H "Authorization: Bearer ${openai_api_key}" | grep -q "200"; then
    log.info "Updated and confirmed OpenAI API key."
  else
    log.error "Failed to authenticate with: ${openai_api_key}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      cli.cmd.setup._openai_api_key "${tmp_file}"
    else
      log.error "Exiting the setup process."
      exit 1
    fi
  fi
}
cli.cmd.setup._checkout_project() {
  local checked_out=""
  local should_checkout_project="$(gum.confirm_checkout_project)"
  if [[ ${should_checkout_project} = true ]]; then
    local projects=()
    for project in "${HOME}"/.solos/projects/*; do
      if [[ -d ${project} ]]; then
        projects+=("$(basename ${project})")
      fi
    done
    local chosen_project="$(gum.project_choices "<create>" "${projects[@]}")"
    if [[ ${chosen_project} = "<create>" ]]; then
      local new_project_name="$(gum.new_project_name_input)"
      if [[ -n ${new_project_name} ]]; then
        while [[ -d "${HOME}/.solos/projects/${new_project_name}" ]]; do
          log.error "Project already exists: ${new_project_name}. Try something different."
          new_project_name="$(gum.new_project_name_input)"
          if [[ -z ${new_project_name} ]]; then
            break
          fi
        done
      fi
      if [[ -n ${new_project_name} ]]; then
        checked_out="${new_project_name}"
      fi
    elif [[ -n ${chosen_project} ]]; then
      checked_out="${chosen_project}"
    fi
  fi
  if [[ -n ${checked_out} ]]; then
    cli.global_store.set "checked_out_project" "${checked_out}"
  fi
}
cli.cmd.setup() {
  local curr_git_hash="$(cli.utils.git_hash)"
  if [[ -z ${curr_git_hash} ]]; then
    exit 1
  fi
  local setup_at_git_hash="$(cli.global_store.get "setup_at_git_hash")"
  local should_proceed=false
  if [[ -n ${setup_at_git_hash} ]]; then
    if [[ ${setup_at_git_hash} != ${curr_git_hash} ]]; then
      cli.cmd.setup._print_curr_setup
      should_proceed=true
    else
      cli.cmd.setup._print_curr_setup
      should_proceed="$(gum.confirm_overwriting_setup)"
    fi
  else
    should_proceed=true
  fi
  if [[ ${should_proceed} = false ]]; then
    log.info "Exiting the setup process. Nothing was changed."
    exit 0
  fi

  local gh_token_tmp_file="$(mktemp -q)"
  local gh_email_tmp_file="$(mktemp -q)"
  local gh_name_tmp_file="$(mktemp -q)"
  local openai_api_key_tmp_file="$(mktemp -q)"
  cli.cmd.setup._gh_token "${gh_token_tmp_file}"
  cli.cmd.setup._gh_email "${gh_email_tmp_file}"
  cli.cmd.setup._gh_name "${gh_name_tmp_file}"
  cli.cmd.setup._openai_api_key "${openai_api_key_tmp_file}"
  rm -rf "${HOME}/.solos/config"
  rm -rf "${HOME}/.solos/secrets"
  cli.config_store.set "gh_email" "$(cat "${gh_email_tmp_file}")"
  cli.config_store.set "gh_name" "$(cat "${gh_name_tmp_file}")"
  cli.secrets_store.set "gh_token" "$(cat "${gh_token_tmp_file}")"
  local openai_api_key="$(cat "${openai_api_key_tmp_file}" || echo "")"
  if [[ -n ${openai_api_key} ]]; then
    cli.secrets_store.set "openai_api_key" "${openai_api_key}"
  fi
  cli.global_store.set "setup_at_git_hash" "${curr_git_hash}"
  if [[ ${cli__is_running_in_shell} = false ]]; then
    cli.cmd.setup._checkout_project
  fi
}
#---------------------------------------------
# LIB:PROJECT: Project related helper methods
#---------------------------------------------
cli.project.prune() {
  local tmp_dir="$(mktemp -d -q)"
  local vscode_workspace_file="${HOME}/.solos/projects/${cli__project_name}/.vscode/solos-${cli__project_name}.code-workspace"
  if [[ ! -f ${vscode_workspace_file} ]]; then
    log.error "Unexpected error: no code workspace file: ${vscode_workspace_file}"
    exit 1
  fi
  local tmp_vscode_workspace_file="${tmp_dir}/$(basename ${vscode_workspace_file})"
  cp -f "${vscode_workspace_file}" "${tmp_vscode_workspace_file}"
  local apps="$(jq '.folders[] | select(.name | startswith("app."))' "${tmp_vscode_workspace_file}" | grep -Po '"name": "\K[^"]*' | cut -d'.' -f2)"
  local nonexistent_apps=()
  while read -r app; do
    if [[ -z ${app} ]]; then
      continue
    fi
    local app_dir="${HOME}/.solos/projects/${cli__project_name}/apps/${app}"
    if [[ ! -d ${app_dir} ]]; then
      nonexistent_apps+=("${app}")
    fi
  done <<<"${apps}"
  if [[ ${#nonexistent_apps[@]} -eq 0 ]]; then
    return 0
  fi
  log.info "Found nonexistent apps: ${nonexistent_apps[*]}"
  for nonexistent_app in "${nonexistent_apps[@]}"; do
    jq 'del(.folders[] | select(.name == "App.'"${nonexistent_app}"'"))' "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
    mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
  done
  if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
    log.error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
    exit 1
  fi
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  log.info "Removed nonexistent apps from the code workspace file."
  return 0
}
#--------------------------------------------------------------------
#                            RUN IT
#--------------------------------------------------------------------
__MAIN__() {
  cli.argparse.requirements
  cli.argparse.cmd "$@"
  cli.argparse.validate_opts
  if ! cli.argparse.ingest; then
    exit 1
  fi
  if [[ -z ${cli__cmd} ]]; then
    exit 1
  fi
  if ! command -v "cli.cmd.${cli__cmd}" &>/dev/null; then
    log.error "Unexpected error: no implementation for cmd.${cli__cmd} exists."
    exit 1
  fi
  "cli.cmd.${cli__cmd}" || true
  if [[ -n ${cli__project_name} ]]; then
    if ! cli.project.prune; then
      log.error "Unexpected error: something failed while pruning nonexistent apps from the vscode workspace file."
    fi
  fi
}

__MAIN__ "$@"
