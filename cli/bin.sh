#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
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
bin__is_running_in_shell=false
for arg in "$@"; do
  if [[ ${arg} = "--restricted-shell" ]]; then
    bin__is_running_in_shell=true
  fi
done
bin__restricted_args=()
while [[ $# -gt 0 ]]; do
  if [[ ${1} != --restricted-* ]]; then
    bin__restricted_args+=("${1}")
  fi
  shift
done
set -- "${bin__restricted_args[@]}"
#--------------------------------------------------------------------
# LIB:GLOBAL: Stuff that everything across all SolOS projects needs.
#--------------------------------------------------------------------
bin.global_store.del() {
  local store_dir="${HOME}/.solos/data/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}
bin.global_store.get() {
  local store_dir="${HOME}/.solos/data/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}
bin.global_store.set() {
  local store_dir="${HOME}/.solos/data/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}
#-------------------------------------------------------------------
# bin__users_home_dir: The user's home directory on their host machine
# bin__cmd: The command to run. Populated in the argparse functions.
# bin__allowed_options: An array of the allowed options for the current command.
# bin__options: An array of the options passed to the CLI.
# bin__project_name: The name of the project being worked on.
# bin__project_app: The name of the app within the project being worked on.
#-------------------------------------------------------------------
bin__restricted_args=()
for arg in "$@"; do
  if [[ ${arg} != --restricted-* ]]; then
    bin__restricted_args+=("${arg}")
  fi
done
bin__users_home_dir="$(bin.global_store.get "users_home_dir" "/root")"
bin__cmd=""
bin__allowed_options=()
bin__options=()
bin__project_name=""
bin__project_app=""
#-------------------------------------------------------------------
# Source any dependencies that are required for the CLI to function.
# These are placed below the definition of bin__users_home_dir because
# they might rely on it.
#-------------------------------------------------------------------
. "${HOME}/.solos/src/shared/gum.sh"
. "${HOME}/.solos/src/shared/log.sh"
#-------------------------------------------------
# LIB:USAGE: CLI Help Information
#-------------------------------------------------
bin.usage.cmds.help() {
  cat <<EOF
USAGE: solos <command> <args..>

DESCRIPTION:

Manage your SolOS projects and apps.

COMMANDS:

checkout                 - Switch to a pre-existing project or initialize a new one.
app                      - Initializes or checks out a project app.
shell                    - Start a SolOS shell session with ~/.solos/rcfiles/.bashrc sourced.
shell-minimal            - Start a SolOS shell session without sourcing ~/.solos/rcfiles/.bashrc.
init                     - Configure SolOS for things like Git credentials, API keys, etc.

Source: https://github.com/InterBolt/solos
EOF
}
bin.usage.checkout.help() {
  cat <<EOF
USAGE: solos checkout <project>

DESCRIPTION:

Creates a new project if one doesn't exist and then switches to it. The project name \
is cached in the CLI so that all future commands operate against it. Think git checkout.

EOF
}
bin.usage.app.help() {
  cat <<EOF
USAGE: solos app <app_name>

DESCRIPTION:

Initialize a new app within a project if the app doesn't already exist. If it does, \
it will checkout and re-install env dependencies for the app.

EOF
}
bin.usage.shell.help() {
  cat <<EOF
USAGE: solos shell

DESCRIPTION:

Loads a interactive bash shell with the RC file at ~/.solos/rcfiles/.bashrc sourced.

EOF
}
bin.usage.shell_minimal.help() {
  cat <<EOF
USAGE: solos shell-minimal

DESCRIPTION:

Loads a interactive bash shell without a RC file.

EOF
}
bin.usage.init.help() {
  cat <<EOF
USAGE: solos init

DESCRIPTION:

Configure SolOS for things like Git credentials, API keys, etc.

EOF
}
#------------------------------------------------------------
# LIB:ARGPARSE: Converts arguments into usable variables
#------------------------------------------------------------
bin.argparse._is_valid_help_command() {
  if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]; then
    return 0
  else
    return 1
  fi
}
bin.argparse._allowed_cmds() {
  local allowed_cmds=()
  for cmd in $(compgen -A function | grep "bin.usage.*.help"); do
    local cmd_name=$(echo "${cmd}" | awk -F '.' '{print $3}' | tr '_' '-')
    if [[ ${cmd_name} != "cmds" ]]; then
      allowed_cmds+=("${cmd_name}")
    fi
  done
  echo "${allowed_cmds[@]}"
}
bin.argparse.cmd() {
  local allowed_cmds=($(bin.argparse._allowed_cmds))
  if [[ -z "$1" ]]; then
    log.error "No command supplied."
    bin.usage.cmds.help
    exit 0
  fi
  if bin.argparse._is_valid_help_command "$1"; then
    bin.usage.cmds.help
    exit 0
  fi
  local post_command_arg_index=0
  while [[ "$#" -gt 0 ]]; do
    if bin.argparse._is_valid_help_command "$1"; then
      if [[ -z ${bin__cmd} ]]; then
        log.error "invalid command, use \`solos --help\` to see available commands."
        exit 1
      fi
      bin.usage."${bin__cmd}".help
      exit 0
    fi
    case "$1" in
    --*)
      local key=$(echo "$1" | awk -F '=' '{print $1}' | sed 's/^--//')
      local value=$(echo "$1" | awk -F '=' '{print $2}')
      bin__options+=("${key}=${value}")
      ;;
    *)
      if [[ -z "$1" ]]; then
        break
      fi
      if [[ -n "${bin__cmd}" ]]; then
        post_command_arg_index=$((post_command_arg_index + 1))
        bin__options+=("argv${post_command_arg_index}=$1")
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
        bin__cmd="${cmd_name}"
      fi
      ;;
    esac
    shift
  done
}
bin.argparse.requirements() {
  local allowed_cmds=($(bin.argparse._allowed_cmds))
  for cmd_name in $(
    bin.usage.cmds.help |
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
    for cmd_option in $(bin.usage."${cmd}".help | grep -E "^--" | awk '{print $1}'); do
      cmd_option="$(echo "${cmd_option}" | awk -F '=' '{print $1}' | sed 's/^--//')"
      if [[ ${first} = true ]]; then
        opts="${opts}${cmd_option}"
      else
        opts="${opts},${cmd_option}"
      fi
      first=false
    done
    bin__allowed_options+=("${opts})")
  done
}
bin.argparse.validate_opts() {
  if [[ -n ${bin__options[0]} ]]; then
    for cmd_option in "${bin__options[@]}"; do
      for allowed_cmd_option in "${bin__allowed_options[@]}"; do
        cmd_name=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $1}')
        cmd_options=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
        if [[ ${cmd_name} = "${bin__cmd}" ]]; then
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
            echo "Command option: ${cmd_option} is not allowed for command: ${bin__cmd}."
            echo ""
            exit 1
          fi
        fi
      done
    done
  fi
}
bin.argparse.ingest() {
  local checked_out_project="$(bin.global_store.get "checked_out_project")"
  if [[ ${bin__cmd} = "checkout" ]] && [[ ${#bin__options[@]} -eq 0 ]]; then
    if [[ -z ${checked_out_project} ]]; then
      log.error "No project currently checked out."
      return 1
    fi
    bin__options=("argv1=${checked_out_project}")
  fi
  for i in "${!bin__options[@]}"; do
    case "${bin__options[$i]}" in
    argv1=*)
      if [[ ${bin__cmd} = "app" ]]; then
        bin__project_app="${bin__options[$i]#*=}"
      fi
      if [[ ${bin__cmd} = "checkout" ]]; then
        bin__project_name="${bin__options[$i]#*=}"
        # If we're running from the SolOS shell, prevent checking out a different bin.project.
        # This is not the best solution but one that will prevent hair-pulling bugs/inconsistencies
        # while we work on a better solution.
        if [[ ${bin__is_running_in_shell} = true ]]; then
          if [[ -n ${bin__project_name} ]] && [[ ${checked_out_project} != "${bin__project_name}" ]]; then
            log.error \
              "Usage error: \`solos checkout ${bin__project_name}\` must be run on your host machine."
            return 1
          fi
          if [[ -n ${checked_out_project} ]]; then
            bin__project_name="${checked_out_project}"
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
bin.config_store.del() {
  local store_dir="${HOME}/.solos/config"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}
bin.config_store.get() {
  local store_dir="${HOME}/.solos/config"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}
bin.config_store.set() {
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
bin.project_store.del() {
  if [[ -z ${bin__project_name} ]]; then
    log.error "bin__project_name is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${bin__project_name} ]]; then
    log.error "Project not found: ${bin__project_name}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${bin__project_name}/data/store"
  if [[ -z $1 ]]; then
    log.warn "No key provided. Nothing to delete."
    return 0
  fi
  rm -f "${project_store_dir}/$1"
}
bin.project_store.get() {
  if [[ -z ${bin__project_name} ]]; then
    log.error "bin__project_name is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${bin__project_name} ]]; then
    log.error "Project not found: ${bin__project_name}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${bin__project_name}/data/store"
  local project_store_file="${project_store_dir}/$1"
  if [[ -f ${project_store_file} ]]; then
    cat "${project_store_file}"
  else
    echo ""
  fi
}
bin.project_store.set() {
  if [[ -z ${bin__project_name} ]]; then
    log.error "bin__project_name is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${bin__project_name} ]]; then
    log.error "Project not found: ${bin__project_name}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${bin__project_name}/data/store"
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
bin.secrets_store.del() {
  local store_dir="${HOME}/.solos/secrets"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}
bin.secrets_store.get() {
  local store_dir="${HOME}/.solos/secrets"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}
bin.secrets_store.set() {
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
bin.ssh.create() {
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
bin.utils.template_variables() {
  local dir_or_file="$1"
  local eligible_files=()
  if [[ -d ${dir_or_file} ]]; then
    for file in "${dir_or_file}"/*; do
      if [[ -d ${file} ]]; then
        bin.utils.template_variables "${file}"
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
    bin_vars=$(grep -o "___bin__[a-z0-9_]*___" "${file}" | sed 's/___//g')
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
bin.utils.git_hash() {
  local source_code_path="${HOME}/.solos/src"
  if [[ ! -d "${source_code_path}" ]]; then
    log.error "Unexpected error: nothing found at ${source_code_path}. Cannot generate a version hash."
    exit 1
  fi
  git -C "${source_code_path}" rev-parse --short HEAD | cut -c1-7 || echo ""
}
bin.utils.pretty_print_dir_files() {
  local dir="$1"
  local tilde_dir="${dir/#\/root/\~}"
  for store_dir_file in "${dir}"/*; do
    local filename="$(basename ${store_dir_file})"
    printf "\033[0;32m%s\033[0m\n" "${tilde_dir}/${filename}: $(cat "${store_dir_file}" 2>/dev/null || echo "")"
  done
}
#----------------------------------------------------------------------------
# LIB:CMD: CLI command implementations and their specific helper functions.
#          at cmd.<command_name>_<subcommand_name>.
#----------------------------------------------------------------------------
bin.cmd.app._remove_app_from_code_workspace() {
  local workspace_file="$1"
  jq 'del(.folders[] | select(.name == "'"${bin__project_name}"'.'"${bin__project_app}"'"))' "${workspace_file}" >"${workspace_file}.tmp"
  if ! jq . "${workspace_file}.tmp" >/dev/null; then
    log.error "Failed to validate the updated code workspace file: ${workspace_file}.tmp"
    exit 1
  fi
  mv "${workspace_file}.tmp" "${workspace_file}"
}
bin.cmd.app._get_path_to_app() {
  local path_to_apps="${HOME}/.solos/projects/${bin__project_name}/apps"
  mkdir -p "${path_to_apps}"
  echo "${path_to_apps}/${bin__project_app}"
}
bin.cmd.app._init() {
  if [[ ! ${bin__project_app} =~ ^[a-z_-]*$ ]]; then
    log.error "Invalid app name. App names must be lowercase and can only contain letters, hyphens, and underscores."
    exit 1
  fi
  # Do this to prevent when the case where the user wants to create an app but has the wrong
  # project checked out. They can still fuck it up but at least we provide some guardrail.
  local should_continue="$(gum.confirm_new_app "${bin__project_name}" "${bin__project_app}")"
  if [[ ${should_continue} = false ]]; then
    log.error "${bin__project_name}:${bin__project_app} - Aborted."
    exit 1
  fi
  local tmp_app_dir="$(mktemp -d -q)"
  local tmp_misc_dir="$(mktemp -d -q)"
  local tmp_file="$(mktemp -d -q)/repo"
  if ! gum.repo_url >"${tmp_file}"; then
    log.error "${bin__project_name}:${bin__project_app} - Aborted."
    exit 1
  fi
  local repo_url="$(cat "${tmp_file}")"
  if [[ -n ${repo_url} ]]; then
    if ! git clone "$(cat ${tmp_file})" "${tmp_app_dir}" >/dev/null; then
      log.error "Failed to clone the app's repository."
      exit 1
    fi
    log.info "${bin__project_name}:${bin__project_app} - Cloned the app's repository."
  else
    log.warn "${bin__project_name}:${bin__project_app} - No repo url supplied. Creating an empty app directory."
  fi
  cat <<EOF >"${tmp_app_dir}/solos.preexec.sh"
#!/usr/bin/env bash

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
echo "Hello from the pre-exec script for app: ${bin__project_app}"
EOF
  cat <<EOF >"${tmp_app_dir}/solos.postexec.sh"
#!/usr/bin/env bash

#########################################################################################################
## This script is executed after any command run in the SolOS's shell when the working directory is a 
## the parent directory or a subdirectory of the app's directory. The output of this script is not
## included in your command's stdout/err but is visible in the terminal.
##
## Important note: Idempotency is YOUR responsibility.
#########################################################################################################

# Write your code below:
echo "Hello from the post-exec script for app: ${bin__project_app}"
EOF
  log.info "${bin__project_name}:${bin__project_app} - Created the pre-exec script."
  local app_dir="$(bin.cmd.app._get_path_to_app)"
  local vscode_workspace_file="${HOME}/.solos/projects/${bin__project_name}/.vscode/${bin__project_name}.code-workspace"
  local tmp_vscode_workspace_file="${tmp_misc_dir}/$(basename ${vscode_workspace_file})"
  if [[ ! -f "${vscode_workspace_file}" ]]; then
    log.error "Unexpected error: no code workspace file: ${vscode_workspace_file}"
    exit 1
  fi
  cp -f "${vscode_workspace_file}" "${tmp_vscode_workspace_file}"
  # The goal is to remove the app and then add it back to the beginning of the folders array.
  # This gives the best UX in VS Code since a new terminal will automatically assume the app's dir context.
  bin.cmd.app._remove_app_from_code_workspace "${tmp_vscode_workspace_file}"
  jq \
    --arg app_name "${bin__project_app}" \
    '.folders |= [{ "name": "app.'"${bin__project_app}"'", "uri": "'"${bin__users_home_dir}"'/.solos/projects/'"${bin__project_name}"'/apps/'"${bin__project_app}"'", "profile": "shell" }] + .' \
    "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
  mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
  if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
    log.error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
    exit 1
  fi

  chmod +x "${tmp_app_dir}/solos.preexec.sh"
  chmod +x "${tmp_app_dir}/solos.postexec.sh"
  log.info "${bin__project_name}:${bin__project_app} - Made the lifecycle scripts executable."

  # Do last to prevent partial app setup.
  mv "${tmp_app_dir}" "${app_dir}"
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  rm -rf "${tmp_misc_dir}"
  log.info "${bin__project_name}:${bin__project_app} - Initialized the app."
}
bin.cmd.app() {
  bin__project_name="$(bin.global_store.get "checked_out_project")"
  if [[ -z ${bin__project_name} ]]; then
    log.error "No project currently checked out."
    exit 1
  fi
  if [[ -z "${bin__project_app}" ]]; then
    log.error "No app name was supplied."
    exit 1
  fi
  if [[ -z "${bin__project_name}" ]]; then
    log.error "A project name is required. Please checkout a project first."
    exit 1
  fi
  local app_dir="$(bin.cmd.app._get_path_to_app)"
  if [[ ! -d ${app_dir} ]]; then
    bin.cmd.app._init
  else
    log.info "${bin__project_name}:${bin__project_app} - App already exists."
  fi
}
bin.cmd.checkout() {
  if [[ -z ${bin__project_name} ]]; then
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
  if [[ ! -d ${HOME}/.solos/projects/${bin__project_name} ]]; then
    local tmp_project_ssh_dir="$(mktemp -d -q)"
    if [[ ! -d ${tmp_project_ssh_dir} ]]; then
      log.error "Unexpected error: no tmp dir was created."
      exit 1
    fi
    bin.ssh.create "default" "${tmp_project_ssh_dir}" || exit 1
    log.info "${bin__project_name} - Created keypair for project"
    mkdir -p "${HOME}/.solos/projects/${bin__project_name}"
    mkdir -p "${HOME}/.solos/projects/${bin__project_name}/data/store"
    echo "# Any plugin names listed below this line will be turned off when working in this project." \
      >"${HOME}/.solos/projects/${bin__project_name}/solos.ignoreplugins"
    cp -a "${tmp_project_ssh_dir}" "${HOME}/.solos/projects/${bin__project_name}/.ssh"
    log.info "${bin__project_name} - Established project directory"
    local vscode_dir="${HOME}/.solos/projects/${bin__project_name}/.vscode"
    mkdir -p "${vscode_dir}"
    local tmp_dir="$(mktemp -d -q)"
    cp "${HOME}/.solos/src/cli/project.code-workspace" "${tmp_dir}/${bin__project_name}.code-workspace"
    if bin.utils.template_variables "${tmp_dir}/${bin__project_name}.code-workspace"; then
      cp -f "${tmp_dir}/${bin__project_name}.code-workspace" "${vscode_dir}/${bin__project_name}.code-workspace"
      log.info "${bin__project_name} - Successfully templated the Visual Studio Code workspace file."
    else
      log.error "${bin__project_name} - Failed to build the code workspace file."
      exit 1
    fi

    local checkout_script="${HOME}/.solos/projects/${bin__project_name}/solos.checkout.sh"
    if [[ -f ${checkout_script} ]]; then
      chmod +x "${checkout_script}"
      if ! "${checkout_script}"; then
        log.warn "${bin__project_name} - Failed to run the checkout script."
      else
        log.info "${bin__project_name} - Checkout out."
      fi
    else
      cat <<EOF >"${checkout_script}"
#!/usr/bin/env bash

######################################################################################################################
## This script runs at two different possible points in time:
## 1) When the \`solos checkout\` command is run from your host machine (checkout is not allowed in the SolOS shell).
## 2) When the shell launches and a project is checked out.

# We can't guarantee that it only runs when the container is initialized but we can safely assume it will never run
# in another project's container.
######################################################################################################################

# Write your code below:
echo "Hello from the checkout script for project: ${bin__project_name}"

EOF
      chmod +x "${checkout_script}"
      log.info "${bin__project_name} - Created the checkout script."
    fi
  fi
  bin.global_store.set "checked_out_project" "${bin__project_name}"
}
bin.cmd.init._print_curr_setup() {
  local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
  echo ""
  echo "${full_line}"
  echo ""
  echo "CURRENT SETUP:"
  echo ""
  bin.utils.pretty_print_dir_files "${HOME}/.solos/config"
  bin.utils.pretty_print_dir_files "${HOME}/.solos/secrets"
  echo ""
  echo "${full_line}"
}
bin.cmd.init() {
  local curr_git_hash="$(bin.utils.git_hash)"
  if [[ -z ${curr_git_hash} ]]; then
    exit 1
  fi
  local setup_at_git_hash="$(bin.global_store.get "setup_at_git_hash")"
  local should_proceed=false
  if [[ -n ${setup_at_git_hash} ]]; then
    if [[ ${setup_at_git_hash} != ${curr_git_hash} ]]; then
      bin.cmd.init._print_curr_setup
      should_proceed=true
    else
      bin.cmd.init._print_curr_setup
      should_proceed="$(gum.confirm_overwriting_setup)"
    fi
  else
    should_proceed=true
  fi
  if [[ ${should_proceed} = false ]]; then
    log.info "Exiting the setup process. Nothing was changed."
    exit 0
  fi
  local checked_out_project=""
  local should_checkout_project="$(gum.confirm_checkout_project)"
  if [[ ${should_checkout_project} = true ]]; then
    local available_projects=()
    for project in "${HOME}"/.solos/projects/*; do
      if [[ -d ${project} ]]; then
        available_projects+=("$(basename ${project})")
      fi
    done
    local selected_project="$(gum.project_choices "<create>" "${available_projects[@]}")"
    if [[ ${selected_project} = "<create>" ]]; then
      local supplied_project_name="$(gum.new_project_name_input)"
      if [[ -n ${supplied_project_name} ]]; then
        while [[ -d "${HOME}/.solos/projects/${supplied_project_name}" ]]; do
          log.error "Project already exists: ${supplied_project_name}. Try something different."
          supplied_project_name="$(gum.new_project_name_input)"
          if [[ -z ${supplied_project_name} ]]; then
            break
          fi
        done
      fi
      if [[ -n ${supplied_project_name} ]]; then
        checked_out_project="${supplied_project_name}"
      fi
    elif [[ -n ${selected_project} ]]; then
      checked_out_project="${selected_project}"
    fi
  fi
  bin.global_store.set "setup_at_git_hash" "${curr_git_hash}"
  if [[ -n ${checked_out_project} ]]; then
    bin.global_store.set "checked_out_project" "${checked_out_project}"
    /bin/bash -c "${HOME}/.solos/src/cli/bin.sh checkout ${checked_out_project}"
  fi
}
#---------------------------------------------
# LIB:PROJECT: Project related helper methods
#---------------------------------------------
bin.project.prune() {
  local tmp_dir="$(mktemp -d -q)"
  local vscode_workspace_file="${HOME}/.solos/projects/${bin__project_name}/.vscode/${bin__project_name}.code-workspace"
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
    local app_dir="${HOME}/.solos/projects/${bin__project_name}/apps/${app}"
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
bin.main() {
  bin.argparse.requirements
  bin.argparse.cmd "$@"
  bin.argparse.validate_opts
  if ! bin.argparse.ingest; then
    exit 1
  fi
  if [[ -z ${bin__cmd} ]]; then
    exit 1
  fi
  if ! command -v "bin.cmd.${bin__cmd}" &>/dev/null; then
    log.error "Unexpected error: no implementation for cmd.${bin__cmd} exists."
    exit 1
  fi
  "bin.cmd.${bin__cmd}" || true
  if [[ -n ${bin__project_name} ]]; then
    if ! bin.project.prune; then
      log.error "Unexpected error: something failed while pruning nonexistent apps from the vscode workspace file."
    fi
  fi
}

bin.main "$@"
