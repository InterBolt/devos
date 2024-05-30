#!/usr/bin/env bash

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

set -o errexit

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

shopt -s dotglob

#-------------------------------------------------------------------
# This is useful to confirm that our script is executable and the
# symlink worked on installation.
#-------------------------------------------------------------------
for arg in "$@"; do
  if [[ ${arg} = "--restricted-noop" ]]; then
    exit 0
  fi
done
vRUN_FROM_SHELL=false
for arg in "$@"; do
  if [[ ${arg} = "--restricted-shell" ]]; then
    vRUN_FROM_SHELL=true
  fi
done
vUSERS_ARGS=()
while [[ $# -gt 0 ]]; do
  if [[ ${1} != --restricted-* ]]; then
    vUSERS_ARGS+=("${1}")
  fi
  shift
done
set -- "${vUSERS_ARGS[@]}"
#-------------------------------------------
# LIB:GLOBAL: Info Shared between Projects
#-------------------------------------------
global_store.del() {
  local store_dir="${HOME}/.solos/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  rm -f "${storage_file}"
}
global_store.get() {
  local store_dir="${HOME}/.solos/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  cat "${storage_file}" 2>/dev/null || echo ""
}
global_store.set() {
  local store_dir="${HOME}/.solos/store"
  mkdir -p "${store_dir}"
  local storage_file="${store_dir}/$1"
  if [[ ! -f ${storage_file} ]]; then
    touch "${storage_file}"
  fi
  echo "$2" >"${storage_file}"
}
#-------------------------------------------------------------------
# vUSERS_HOME_DIR: The user's home directory on their host machine
# vCMD: The command to run. Populated in the argparse functions.
# vOPTIONS: An array of the options passed to the CLI.
# vPROJECT_NAME: The name of the project being worked on.
#-------------------------------------------------------------------
vUSERS_ARGS=()
for arg in "$@"; do
  if [[ ${arg} != --restricted-* ]]; then
    vUSERS_ARGS+=("${arg}")
  fi
done
vUSERS_HOME_DIR="$(global_store.get "users_home_dir" "/root")"
vCMD=""
vALLOWED_OPTIONS=()
vOPTIONS=()
vPROJECT_NAME=""
vPROJECT_APP=""
#-------------------------------------------------------------------
# Source any dependencies that are required for the CLI to function.
# These are placed below the definition of vUSERS_HOME_DIR because
# they rely on it.
#-------------------------------------------------------------------
. "${HOME}/.solos/src/tools/pkgs/gum.sh"
. "${HOME}/.solos/src/tools/log.sh"
#---------------------------------
# LIB:USAGE: CLI Help Information
#---------------------------------
usage.help() {
  cat <<EOF
USAGE: solos <command> <args..>

DESCRIPTION:

A CLI to manage SolOS projects on your local machine or container.

COMMANDS:

checkout                 - Switch to a pre-existing project or initialize a new one.
app                      - Initializes or checks out a project app.
shell                    - Start a SolOS shell session with ~/.solos/profile/.bashrc sourced.
shell-minimal            - Start a SolOS shell session without sourcing ~/.solos/profile/.bashrc.
try                      - (DEV ONLY) Undocumented.

Source: https://github.com/InterBolt/solos
EOF
}
usage.cmd.checkout.help() {
  cat <<EOF
USAGE: solos checkout <project>

DESCRIPTION:

Creates a new project if one doesn't exist and then switches to it. The project name \
is cached in the CLI so that all future commands operate against it. Think git checkout.

EOF
}
usage.cmd.app.help() {
  cat <<EOF
USAGE: solos app <app_name>

DESCRIPTION:

Initialize a new app within a project if the app doesn't already exist. If it does, \
it will checkout and re-install env dependencies for the app.

EOF
}
usage.cmd.shell.help() {
  cat <<EOF
USAGE: solos shell

DESCRIPTION:

Loads a interactive bash shell with the RC file at ~/.solos/profile/.bashrc sourced.

EOF
}
usage.cmd.shell_minimal.help() {
  cat <<EOF
USAGE: solos shell-minimal

DESCRIPTION:

Loads a interactive bash shell without a RC file.

EOF
}
usage.cmd.try.help() {
  cat <<EOF
USAGE: solos try

DESCRIPTION:

Undocumented.

EOF
}
#-------------------------------
# LIB:ARGPARSE: Parse CLI Args
#-------------------------------
argparse._is_valid_help_command() {
  if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]; then
    return 0
  else
    return 1
  fi
}
argparse._allowed_cmds() {
  local allowed_cmds=()
  for cmd in $(compgen -A function | grep "usage.cmd.*.help"); do
    allowed_cmds+=("$(echo "${cmd}" | awk -F '.' '{print $3}' | tr '_' '-')")
  done
  echo "${allowed_cmds[@]}"
}
argparse.cmd() {
  local allowed_cmds=($(argparse._allowed_cmds))
  if [[ -z "$1" ]]; then
    log_error "No command supplied."
    usage.help
    exit 0
  fi
  if argparse._is_valid_help_command "$1"; then
    usage.help
    exit 0
  fi
  local post_command_arg_index=0
  while [[ "$#" -gt 0 ]]; do
    if argparse._is_valid_help_command "$1"; then
      if [[ -z ${vCMD} ]]; then
        log_error "invalid command, use \`solos --help\` to see available commands."
        exit 1
      fi
      usage.cmd."${vCMD}".help
      exit 0
    fi
    case "$1" in
    --*)
      local key=$(echo "$1" | awk -F '=' '{print $1}' | sed 's/^--//')
      local value=$(echo "$1" | awk -F '=' '{print $2}')
      vOPTIONS+=("${key}=${value}")
      ;;
    *)
      if [[ -z "$1" ]]; then
        break
      fi
      if [[ -n "${vCMD}" ]]; then
        post_command_arg_index=$((post_command_arg_index + 1))
        vOPTIONS+=("argv${post_command_arg_index}=$1")
        break
      fi
      local cmd_name=$(echo "$1" | tr '-' '_')
      local is_allowed=false
      for allowed_cmd_name in "${allowed_cmds[@]}"; do
        if [[ ${cmd_name} = ${allowed_cmd_name} ]]; then
          is_allowed=true
        fi
      done
      if [[ ${is_allowed} = "false" ]]; then
        log_error "Unknown command: $1"
      else
        vCMD="${cmd_name}"
      fi
      ;;
    esac
    shift
  done
}
argparse.requirements() {
  local allowed_cmds=($(argparse._allowed_cmds))
  for cmd_name in $(
    usage.help |
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
    for cmd_option in $(usage.cmd."${cmd}".help | grep -E "^--" | awk '{print $1}'); do
      cmd_option="$(echo "${cmd_option}" | awk -F '=' '{print $1}' | sed 's/^--//')"
      if [[ ${first} = true ]]; then
        opts="${opts}${cmd_option}"
      else
        opts="${opts},${cmd_option}"
      fi
      first=false
    done
    vALLOWED_OPTIONS+=("${opts})")
  done
}
argparse.validate_opts() {
  if [[ -n ${vOPTIONS[0]} ]]; then
    for cmd_option in "${vOPTIONS[@]}"; do
      for allowed_cmd_option in "${vALLOWED_OPTIONS[@]}"; do
        cmd_name=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $1}')
        cmd_options=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
        if [[ ${cmd_name} = ${vCMD} ]]; then
          is_cmd_option_allowed=false
          flag_name="$(echo "${cmd_option}" | awk -F '=' '{print $1}')"
          for cmd_option in "$(echo "${cmd_options}" | tr ',' '\n')"; do
            if [[ ${cmd_option} = ${flag_name} ]]; then
              is_cmd_option_allowed=true
            fi
          done
          if [[ ${flag_name} = "argv"* ]]; then
            is_cmd_option_allowed=true
          fi
          if [[ ${is_cmd_option_allowed} = false ]]; then
            echo ""
            echo "Command option: ${cmd_option} is not allowed for command: ${vCMD}."
            echo ""
            exit 1
          fi
        fi
      done
    done
  fi
}
argparse.ingest() {
  local checked_out_project="$(global_store.get "checked_out_project")"
  if [[ ${vCMD} = "checkout" ]] && [[ ${#vOPTIONS[@]} -eq 0 ]]; then
    if [[ -z ${checked_out_project} ]]; then
      log_error "No project currently checked out."
      return 1
    fi
    vOPTIONS=("argv1=${checked_out_project}")
  fi
  for i in "${!vOPTIONS[@]}"; do
    case "${vOPTIONS[$i]}" in
    argv1=*)
      if [[ ${vCMD} = "app" ]]; then
        vPROJECT_APP="${vOPTIONS[$i]#*=}"
      fi
      if [[ ${vCMD} = "checkout" ]]; then
        vPROJECT_NAME="${vOPTIONS[$i]#*=}"
        # If we're running from the SolOS shell, prevent checking out a different project.
        # This is not the best solution but one that will prevent hair-pulling bugs/inconsistencies
        # while we work on a better solution.
        if [[ ${vRUN_FROM_SHELL} = true ]]; then
          if [[ -n ${vPROJECT_NAME} ]] && [[ ${checked_out_project} != "${vPROJECT_NAME}" ]]; then
            log_error \
              "You cannot checkout a different project within a dockerized SolOS shell. Run on your host machine instead."
            return 1
          fi
          if [[ -n ${checked_out_project} ]]; then
            vPROJECT_NAME="${checked_out_project}"
          fi
        fi
      fi
      ;;
    esac
  done
}
#--------------------------------------------
# LIB:PROJECT_STORE: Information per project
#--------------------------------------------
project_store.del() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/store"
  rm -f "${project_store_dir}/$1"
}
project_store.get() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/store"
  local project_store_file="${project_store_dir}/$1"
  if [[ -f ${project_store_file} ]]; then
    cat "${project_store_file}"
  else
    echo ""
  fi
}
project_store.set() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local project_store_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/store"
  local project_store_file="${project_store_dir}/$1"
  if [[ ! -f ${project_store_file} ]]; then
    touch "${project_store_file}"
  fi
  echo "$2" >"${project_store_file}"
}
#-------------------------------------------------
# LIB:PROJECT_SECRETS: Record secrets per project
#-------------------------------------------------
project_secrets.del() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local secrets_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/secrets"
  rm -f "${secrets_dir}/$1"
}
project_secrets.get() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local secrets_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/secrets"
  local secrets_file="${secrets_dir}/$1"
  if [[ -f ${secrets_file} ]]; then
    cat "${secrets_file}"
  else
    echo ""
  fi
}
project_secrets.set() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "vPROJECT_NAME is not set."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    log_error "Project not found: ${vPROJECT_NAME}"
    exit 1
  fi
  local secrets_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/secrets"
  local secrets_file="${secrets_dir}/$1"
  if [[ ! -f ${secrets_file} ]]; then
    touch "${secrets_file}"
  fi
  echo "$2" >"${secrets_file}"
}
#-------------------------------
# LIB:SSH: SSH helper functions
#-------------------------------
ssh._validate() {
  local key_name="$1"
  local ip="$2"
  local project_dir="${HOME}/.solos/projects/${vPROJECT_NAME}"
  if [[ -z ${key_name} ]]; then
    log_error "key_name is required."
    exit 1
  fi
  if [[ -z ${ip} ]]; then
    log_error "ip is required."
    exit 1
  fi
  local key_path="${project_dir}/.ssh/${key_name}.priv"
  if [[ ! -f "${key_path}" ]]; then
    log_error "key file not found: ${key_path}"
    exit 1
  fi
  echo "${key_path}"
}
ssh.cmd() {
  local key_name="$1"
  local ip="$2"
  local cmd="$3"
  local key_path="$(ssh._validate "${key_name}" "${ip}")"
  ssh \
    -i "${key_path}" \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -o UserKnownHostsFile=/dev/null \
    "$@" root@"${ip}" \
    "${cmd}"
}
ssh.rsync() {
  local key_name="$1"
  shift
  local ip="$1"
  shift
  local key_path="$(ssh._validate "${key_name}" "${ip}")"
  rsync --checksum \
    -a \
    -e "ssh \
    -i ${key_path} \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -o UserKnownHostsFile=/dev/null" \
    "$@"
}
ssh.pubkey() {
  local key_name="$1"
  local ssh_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/.ssh"
  if [[ -z ${key_name} ]]; then
    log_error "key_name is required."
    exit 1
  fi
  if [[ ! -d ${ssh_dir} ]]; then
    log_error "ssh directory not found: ${ssh_dir}"
    exit 1
  fi
  local pubkey_path="${ssh_dir}/${key_name}.pub"
  if [[ ! -f "${pubkey_path}" ]]; then
    log_error "key file not found: ${pubkey_path}"
    exit 1
  fi
  cat "${pubkey_path}"
}
ssh.create() {
  local key_name="$1"
  local ssh_dir="${2}"
  mkdir -p "${ssh_dir}"
  local privkey_path="${ssh_dir}/${key_name}.priv"
  local pubkey_path="${ssh_dir}/${key_name}.pub"
  if [[ -z ${key_name} ]]; then
    log_error "key_name is required."
    exit 1
  fi
  if [[ -f ${privkey_path} ]]; then
    log_error "key file already exists: ${privkey_path}"
    exit 1
  fi
  if [[ -f ${pubkey_path} ]]; then
    log_error "key file already exists: ${pubkey_path}"
    exit 1
  fi
  local entry_dir="${PWD}"
  cd "${ssh_dir}" || exit 1
  if ! ssh-keygen -t rsa -q -f "${privkey_path}" -N "" >/dev/null; then
    log_error "Could not create SSH keypair."
    exit 1
  else
    mv "${privkey_path}.pub" "${pubkey_path}"
    chmod 644 "${pubkey_path}"
    chmod 600 "${privkey_path}"
  fi
  cd "${entry_dir}" || exit 1
}
#-----------------------------------------
# LIB:UTILS: Uncategorized helper methods
#-----------------------------------------
utils.template_variables() {
  local dir_or_file="$1"
  local eligible_files=()
  if [[ -d ${dir_or_file} ]]; then
    for file in "${dir_or_file}"/*; do
      if [[ -d ${file} ]]; then
        utils.template_variables "${file}"
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
    bin_vars=$(grep -o "__v[A-Z0-9_]*__" "${file}" | sed 's/__//g')
    for bin_var in ${bin_vars}; do
      if [[ -z ${!bin_var+x} ]]; then
        log_error "Template variables error: ${file} is using an unset variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ -z ${!bin_var} ]]; then
        log_error "Template variables error: ${file} is using an empty variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ ${errored} = "false" ]]; then
        sed -i "s,__${bin_var}__,${!bin_var},g" "${file}"
      fi
    done
  done
  if [[ ${errored} = "true" ]]; then
    exit 1
  fi
}
#-----------------------------------
# LIB:CMD: Command implementations
#-----------------------------------
cmd.app._remove_app_from_code_workspace() {
  local workspace_file="$1"
  jq 'del(.folders[] | select(.name == "'"${vPROJECT_NAME}"'.'"${vPROJECT_APP}"'"))' "${workspace_file}" >"${workspace_file}.tmp"
  if ! jq . "${workspace_file}.tmp" >/dev/null; then
    log_error "Failed to validate the updated code workspace file: ${workspace_file}.tmp"
    exit 1
  fi
  mv "${workspace_file}.tmp" "${workspace_file}"
}
cmd.app._get_path_to_app() {
  local path_to_apps="${HOME}/.solos/projects/${vPROJECT_NAME}/apps"
  mkdir -p "${path_to_apps}"
  echo "${path_to_apps}/${vPROJECT_APP}"
}
cmd.app._init() {
  if [[ ! ${vPROJECT_APP} =~ ^[a-z_-]*$ ]]; then
    log_error "Invalid app name. App names must be lowercase and can only contain letters, hyphens, and underscores."
    exit 1
  fi
  # Do this to prevent when the case where the user wants to create an app but has the wrong
  # project checked out. They can still fuck it up but at least we provide some guardrail.
  local should_continue="$(gum_confirm_new_app "${vPROJECT_NAME}" "${vPROJECT_APP}")"
  if [[ ${should_continue} = false ]]; then
    log_error "${vPROJECT_NAME}:${vPROJECT_APP} - Aborted."
    exit 1
  fi
  local tmp_app_dir="$(mktemp -d -q)"
  local tmp_misc_dir="$(mktemp -d -q)"
  local tmp_file="$(mktemp -d -q)/repo"
  if ! gum_repo_url >"${tmp_file}"; then
    log_error "${vPROJECT_NAME}:${vPROJECT_APP} - Aborted."
    exit 1
  fi
  local repo_url="$(cat "${tmp_file}")"
  if [[ -n ${repo_url} ]]; then
    if ! git clone "$(cat ${tmp_file})" "${tmp_app_dir}" >/dev/null; then
      log_error "Failed to clone the app's repository."
      exit 1
    fi
    log_info "${vPROJECT_NAME}:${vPROJECT_APP} - Cloned the app's repository."
  else
    log_warn "${vPROJECT_NAME}:${vPROJECT_APP} - No repo url supplied. Creating an empty app directory."
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
echo "Hello from the pre-exec script for app: ${vPROJECT_APP}"
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
echo "Hello from the post-exec script for app: ${vPROJECT_APP}"
EOF
  log_info "${vPROJECT_NAME}:${vPROJECT_APP} - Created the pre-exec script."
  local app_dir="$(cmd.app._get_path_to_app)"
  local vscode_workspace_file="${HOME}/.solos/projects/${vPROJECT_NAME}/.vscode/solos-${vPROJECT_NAME}.code-workspace"
  local tmp_vscode_workspace_file="${tmp_misc_dir}/$(basename ${vscode_workspace_file})"
  if [[ ! -f "${vscode_workspace_file}" ]]; then
    log_error "Unexpected error: no code workspace file: ${vscode_workspace_file}"
    exit 1
  fi
  cp -f "${vscode_workspace_file}" "${tmp_vscode_workspace_file}"
  # The goal is to remove the app and then add it back to the beginning of the folders array.
  # This gives the best UX in VS Code since a new terminal will automatically assume the app's dir context.
  cmd.app._remove_app_from_code_workspace "${tmp_vscode_workspace_file}"
  jq \
    --arg app_name "${vPROJECT_APP}" \
    '.folders |= [{ "name": "app.'"${vPROJECT_APP}"'", "uri": "'"${vUSERS_HOME_DIR}"'/.solos/projects/'"${vPROJECT_NAME}"'/apps/'"${vPROJECT_APP}"'", "profile": "shell" }] + .' \
    "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
  mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
  if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
    log_error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
    exit 1
  fi

  chmod +x "${tmp_app_dir}/solos.preexec.sh"
  chmod +x "${tmp_app_dir}/solos.postexec.sh"
  log_info "${vPROJECT_NAME}:${vPROJECT_APP} - Made the lifecycle scripts executable."

  # Do last to prevent partial app setup.
  mv "${tmp_app_dir}" "${app_dir}"
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  rm -rf "${tmp_misc_dir}"
  log_info "${vPROJECT_NAME}:${vPROJECT_APP} - Initialized the app."
}
cmd.app() {
  project.checkout
  if [[ -z "${vPROJECT_APP}" ]]; then
    log_error "No app name was supplied."
    exit 1
  fi
  if [[ -z "${vPROJECT_NAME}" ]]; then
    log_error "A project name is required. Please checkout a project first."
    exit 1
  fi
  local app_dir="$(cmd.app._get_path_to_app)"
  if [[ ! -d ${app_dir} ]]; then
    cmd.app._init
  else
    log_info "${vPROJECT_NAME}:${vPROJECT_APP} - App already exists."
  fi
}
cmd.checkout() {
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "No project name was supplied."
    exit 1
  fi
  if [[ ! -d ${HOME}/.solos/projects ]]; then
    mkdir -p "${HOME}/.solos/projects"
    log_info "No projects found. Creating ~/.solos/projects directory."
  fi
  # If the project dir exists, let's assume it was setup ok.
  # We'll use a tmp dir to build up the files so that unexpected errors
  # won't result in a partial project dir.
  if [[ ! -d ${HOME}/.solos/projects/${vPROJECT_NAME} ]]; then
    local tmp_project_ssh_dir="$(mktemp -d -q)"
    if [[ ! -d ${tmp_project_ssh_dir} ]]; then
      log_error "Unexpected error: no tmp dir was created."
      exit 1
    fi
    ssh.create "default" "${tmp_project_ssh_dir}" || exit 1
    log_info "${vPROJECT_NAME} - Created keypair for project"
    mkdir -p "${HOME}/.solos/projects/${vPROJECT_NAME}"
    cp -a "${tmp_project_ssh_dir}" "${HOME}/.solos/projects/${vPROJECT_NAME}/.ssh"
    log_info "${vPROJECT_NAME} - Established project directory"
  fi
  global_store.set "checked_out_project" "${vPROJECT_NAME}"
  local vscode_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/.vscode"
  mkdir -p "${vscode_dir}"
  local tmp_dir="$(mktemp -d -q)"
  cp "${HOME}/.solos/src/solos.code-workspace" "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"
  if utils.template_variables "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"; then
    cp -f "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace" "${vscode_dir}/solos-${vPROJECT_NAME}.code-workspace"
    log_info "${vPROJECT_NAME} - Successfully templated the Visual Studio Code workspace file."
  else
    log_error "${vPROJECT_NAME} - Failed to build the code workspace file."
    exit 1
  fi
  local checkout_script="${HOME}/.solos/projects/${vPROJECT_NAME}/solos.checkout.sh"
  if [[ -f ${checkout_script} ]]; then
    chmod +x "${checkout_script}"
    if ! "${checkout_script}"; then
      log_warn "${vPROJECT_NAME} - Failed to run the checkout script."
    else
      log_info "${vPROJECT_NAME} - Checkout out."
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
echo "Hello from the checkout script for project: ${vPROJECT_NAME}"

EOF
    chmod +x "${checkout_script}"
    log_info "${vPROJECT_NAME} - Created the checkout script."
  fi
}
cmd.try() {
  project.checkout
  log_warn "TODO: implementation needed"
}
#---------------------------------------------
# LIB:PROJECT: Project related helper methods
#---------------------------------------------
project.prune() {
  local tmp_dir="$(mktemp -d -q)"
  local vscode_workspace_file="${HOME}/.solos/projects/${vPROJECT_NAME}/.vscode/solos-${vPROJECT_NAME}.code-workspace"
  if [[ ! -f ${vscode_workspace_file} ]]; then
    log_error "Unexpected error: no code workspace file: ${vscode_workspace_file}"
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
    local app_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/apps/${app}"
    if [[ ! -d ${app_dir} ]]; then
      nonexistent_apps+=("${app}")
    fi
  done <<<"${apps}"
  if [[ ${#nonexistent_apps[@]} -eq 0 ]]; then
    return 0
  fi
  log_info "Found nonexistent apps: ${nonexistent_apps[*]}"
  for nonexistent_app in "${nonexistent_apps[@]}"; do
    jq 'del(.folders[] | select(.name == "App.'"${nonexistent_app}"'"))' "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
    mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
  done
  if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
    log_error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
    exit 1
  fi
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  log_info "Removed nonexistent apps from the code workspace file."
  return 0
}
project.checkout() {
  vPROJECT_NAME="$(global_store.get "checked_out_project")"
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "No project currently checked out."
    exit 1
  fi
}
#--------------------------------------------------------------------
#                            RUN IT
#--------------------------------------------------------------------
__MAIN__() {
  argparse.requirements
  argparse.cmd "$@"
  argparse.validate_opts
  if ! argparse.ingest; then
    exit 1
  fi
  if [[ -z ${vCMD} ]]; then
    exit 1
  fi
  if ! command -v "cmd.${vCMD}" &>/dev/null; then
    log_error "No implementation for ${vCMD} exists."
    exit 1
  fi
  "cmd.${vCMD}" || true
  if [[ -n ${vPROJECT_NAME} ]]; then
    if ! project.prune; then
      log_error "Unexpected error: something failed while pruning nonexistent apps from the vscode workspace file."
    fi
  fi
}

__MAIN__ "$@"
