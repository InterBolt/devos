#!/usr/bin/env bash

set -o errexit

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# Will include dotfiles in globbing.
shopt -s dotglob

# Slots to store returns/responses. Bash don't allow rich return
# types, so we do dis hack shite instead.
vPREV_CURL_RESPONSE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_ERR_MESSAGE=""
vPREV_RETURN=()
vPREV_NEXT_ARGS=()

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

# The directory path of the user's home directory.
# Everything here runs in docker so this is the only way I
# know to get the user's home directory.
# TODO: is there a more standard way to get the user's home directory within
# TODO[c]: a docker container?
vUSERS_HOME_DIR="$(global_store.get "users_home_dir" "/root")"
# Populated by the CLI parsing functions.
vCMD=""
vOPTIONS=()
# Basic project info.
# Most other things are stored in the project's secrets or store.
vPROJECT_NAME=""
vPROJECT_APP=""
vPROJECT_ID=""

# The parsing logic we use for the main CLI commands will need to handle more
# types of use cases and provide stronger UX. As a result, it prone to grow in
# complexity. This flag parser OTOH is used by devs only and doesn't need to be pretty.
misc.flag_parser() {
  vPREV_RETURN=()
  local flag_names=()
  while [[ $# -gt 0 ]] && [[ $1 != "ARGS:" ]]; do
    flag_names+=("$1")
    shift
  done
  if [[ $1 != "ARGS:" ]]; then
    echo "Unexpected error: no 'ARGS:' separator found." >&2
    exit 1
  fi
  shift
  local flag_values=()
  for flag_name in "${flag_names[@]}"; do
    for arg in "$@"; do
      if [[ ${arg} = ${flag_name} ]] || [[ ${arg} = "${flag_name}="* ]]; then
        if [[ ${arg} = *'='* ]]; then
          flag_values+=("${arg#*=}")
        else
          flag_values+=("true")
        fi
        set -- "${@/''"${arg}"''/}"
      else
        flag_values+=("")
      fi
    done
  done

  # Now remove the flags we already parsed.
  local nonempty_args=()
  for arg in "$@"; do
    if [ -n ${arg} ]; then
      nonempty_args+=("${arg}")
    fi
  done
  set -- "${nonempty_args[@]}" || exit 1
  vPREV_NEXT_ARGS=("$@")
  vPREV_RETURN=("${flag_values[@]}")
}

misc.flag_parser \
  --restricted-noop \
  "ARGS:" "$@"
set -- "${vPREV_NEXT_ARGS[@]}" || exit 1
vRESTRICTED_MODE_NOOP=${vPREV_RETURN[0]:-false}
if [[ ${vRESTRICTED_MODE_NOOP} = true ]]; then
  exit 0
fi

. "${HOME}/.solos/src/tools/pkgs/gum.sh"
. "${HOME}/.solos/src/tools/log.sh"

vUSAGE_CMD_HEADER="COMMANDS:"
vUSAGE_OPTS_HEADER="OPTIONS:"
vUSAGE_ALLOWS_CMDS=()
vUSAGE_ALLOWS_OPTIONS=()

usage.help() {
  cat <<EOF
USAGE: solos <command> <args..> [--OPTS...]

DESCRIPTION:

A CLI to manage SolOS projects on your local machine or container.

${vUSAGE_CMD_HEADER}

checkout                 - Switch to a pre-existing project or initialize a new one.
app                      - Initializes or checks out a project app.
provision                - Provision resources for a project (eg. storage, databases, cloud instances, etc).
try                      - (DEV ONLY) Undocumented.

${vUSAGE_OPTS_HEADER}

--assume-yes        - Assume yes for all prompts.

Source: https://github.com/InterBolt/solos
EOF
}
usage.cmd.checkout.help() {
  cat <<EOF
USAGE: solos checkout <project> [--OPTS...]

DESCRIPTION:

Creates a new project if one doesn't exist and then switches to it. The project name \
is cached in the CLI so that all future commands operate against it. Think git checkout.

EOF
}
usage.cmd.app.help() {
  cat <<EOF
USAGE: solos app <app-name> [--OPTS...]

DESCRIPTION:

Initialize a new app within a project if the app doesn't already exist. If it does, \
it will checkout and re-install env dependencies for the app.

EOF
}
usage.cmd.provision.help() {
  cat <<EOF
USAGE: solos provision [--OPTS...]

DESCRIPTION:

Creates the required S3 buckets against your preferred S3-compatible object store.

EOF
}
usage.cmd.try.help() {
  cat <<EOF
USAGE: solos try [--OPTS...]

DESCRIPTION:

Undocumented.

EOF
}
argparse._is_valid_help_command() {
  if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]; then
    echo "true"
  else
    echo "false"
  fi
}
argparse.cmd() {
  if [[ -z "$1" ]]; then
    log_error "No command supplied."
    usage.help
    exit 0
  fi
  if [[ $(argparse._is_valid_help_command "$1") = true ]]; then
    usage.help
    exit 0
  fi
  local post_command_arg_index=0
  while [[ "$#" -gt 0 ]]; do
    if [[ $(argparse._is_valid_help_command "$1") = true ]]; then
      if [[ -z "${vCMD}" ]]; then
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
      for allowed_cmd_name in "${vSELF_USAGE_ALLOWS_CMDS[@]}"; do
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
  for cmd_name in $(
    usage.help |
      grep -A 1000 "${vSELF_USAGE_CMD_HEADER}" |
      grep -v "${vSELF_USAGE_CMD_HEADER}" |
      grep -E "^[a-z]" |
      awk '{print $1}'
  ); do
    cmd_name=$(echo "${cmd_name}" | tr '-' '_')
    if [[ "${cmd_name}" != "help" ]]; then
      vSELF_USAGE_ALLOWS_CMDS+=("${cmd_name}")
    fi
  done
  for cmd in "${vSELF_USAGE_ALLOWS_CMDS[@]}"; do
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
    vSELF_USAGE_ALLOWS_OPTIONS+=("${opts})")
  done
}
argparse.validate_opts() {
  if [[ -n ${vOPTIONS[0]} ]]; then
    for cmd_option in "${vOPTIONS[@]}"; do
      for allowed_cmd_option in "${vSELF_USAGE_ALLOWS_OPTIONS[@]}"; do
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

vS3_API_ENDPOINT="https://api.vultr.com/v2"
vS3_API_TOKEN=""
vS3_CURL_RESPONSE=""

s3._get_object_storage_id() {
  local label="solos-${vPROJECT_ID}"
  local object_storage_id=""
  utils.curl "${vS3_API_ENDPOINT}/object-storage" \
    -X GET \
    -H "Authorization: Bearer ${vS3_API_TOKEN}"
  utils.allow_error_status_code "none"
  local object_storage_labels=$(jq -r '.object_storages[].label' <<<"${vS3_CURL_RESPONSE}")
  local object_storage_ids=$(jq -r '.object_storages[].id' <<<"${vS3_CURL_RESPONSE}")
  for i in "${!object_storage_labels[@]}"; do
    if [[ ${object_storage_labels[$i]} = ${label} ]]; then
      object_storage_id="${object_storage_ids[$i]}"
      break
    fi
  done
  if [[ -n ${object_storage_id} ]]; then
    echo "${object_storage_id}"
  else
    echo ""
  fi
}
s3._get_ewr_cluster_id() {
  local cluster_id=""
  utils.curl "${vS3_API_ENDPOINT}/object-storage/clusters" \
    -X GET \
    -H "Authorization: Bearer ${vS3_API_TOKEN}"
  utils.allow_error_status_code "none"
  local cluster_ids=$(jq -r '.clusters[].id' <<<"${vS3_CURL_RESPONSE}")
  local cluster_regions=$(jq -r '.clusters[].region' <<<"${vS3_CURL_RESPONSE}")
  for i in "${!cluster_regions[@]}"; do
    if [[ ${cluster_regions[$i]} = "ewr" ]]; then
      cluster_id="${cluster_ids[$i]}"
      break
    fi
  done
  echo "${cluster_id}"
}
s3._create_storage() {
  local cluster_id="$1"
  local label="solos-${vPROJECT_ID}"
  utils.curl "${vS3_API_ENDPOINT}/object-storage" \
    -X POST \
    -H "Authorization: Bearer ${vS3_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data '{
        "label" : "'"${label}"'",
        "cluster_id" : '"${cluster_id}"'
      }'
  utils.allow_error_status_code "none"
  local object_storage_id=$(jq -r '.object_storage.id' <<<"${vS3_CURL_RESPONSE}")
  echo "${object_storage_id}"
}
s3.init() {
  local api_key="${1}"
  if [[ -z ${api_key} ]]; then
    log_error "No API key provided."
    exit 1
  fi
  vS3_API_TOKEN="${api_key}"
  local object_storage_id="$(s3._get_object_storage_id)"
  if [[ -z ${object_storage_id} ]]; then
    # Create the storage is the EWR region (east I think?)
    local ewr_cluster_id="$(s3._get_ewr_cluster_id)"
    object_storage_id="$(s3._create_storage "${ewr_cluster_id}")"
  fi
  utils.curl "${vS3_API_ENDPOINT}/object-storage/${object_storage_id}" \
    -X GET \
    -H "Authorization: Bearer ${vS3_API_TOKEN}"
  utils.allow_error_status_code "none"
  jq -r '.object_storage.s3_hostname' <<<"${vS3_CURL_RESPONSE}"
  jq -r '.object_storage.s3_access_key' <<<"${vS3_CURL_RESPONSE}"
  jq -r '.object_storage.s3_secret_key' <<<"${vS3_CURL_RESPONSE}"
  jq -r '.object_storage.label' <<<"${vS3_CURL_RESPONSE}"
}
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
  local ssh_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/.ssh"
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
  else
    mv "${privkey_path}.pub" "${pubkey_path}"
    chmod 644 "${pubkey_path}"
    chmod 600 "${privkey_path}"
  fi
  cd "${entry_dir}" || exit 1
}
utils.generate_secret() {
  openssl rand -base64 32 | tr -dc 'a-z0-9' | head -c 32
}
# Must generate a unique string, 10 characters that is URL safe.
utils.generate_project_id() {
  date +%H:%M:%S:%N | sha256sum | base64 | tr '[:upper:]' '[:lower:]' | head -c 16
}
utils.get_project_id() {
  local project_id_file="${HOME}/.solos/projects/${vPROJECT_NAME}/id"
  if [[ -f ${project_id_file} ]]; then
    cat "${project_id_file}"
  else
    echo ""
  fi
}
# Any variable that is set in this shell will automatically replace any text matching:
# __<VARIABLE_NAME>__ in any file that is passed to this function.
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
utils.curl() {
  vPREV_CURL_ERR_STATUS_CODE=""
  vPREV_CURL_ERR_MESSAGE=""
  vPREV_CURL_RESPONSE=$(
    curl --silent --show-error "$@"
  )
  local error_message="$(jq -r '.error' <<<"${vPREV_CURL_RESPONSE}")"
  if [[ ${error_message} = "null" ]]; then
    echo ""
    return
  fi
  vPREV_CURL_ERR_MESSAGE="${error_message}"
  vPREV_CURL_ERR_STATUS_CODE="$(jq -r '.status' <<<"${vPREV_CURL_RESPONSE}")"
}
utils.allow_error_status_code() {
  # A note on the "none" argument:
  # The benefit of forcing the caller to "say" their intention rather
  # than just leaving the arg list empty is purely for readability.
  if [[ -z $1 ]]; then
    log_error "Missing \`none\` or a list of allowed status codes."
    exit 1
  fi
  local error_message="${vPREV_CURL_ERR_MESSAGE} with status code: ${vPREV_CURL_ERR_STATUS_CODE}"
  local allowed="true"
  if [[ -z ${vPREV_CURL_ERR_STATUS_CODE} ]]; then
    log_info "no error status code found for curl request"
    return
  fi
  if [[ $1 = "none" ]]; then
    allowed=""
    shift
  fi
  local allowed_status_codes=()
  if [[ $# -gt 0 ]]; then
    allowed_status_codes=("$@")
  fi
  for allowed_status_code in "${allowed_status_codes[@]}"; do
    if [[ ${vPREV_CURL_ERR_STATUS_CODE} = "${allowed_status_code}" ]]; then
      allowed="true"
      log_info "set allowed to true for status code: ${allowed_status_code}"
    fi
  done
  if [[ -z ${allowed} ]]; then
    log_error "${error_message}"
    exit 1
  else
    log_warn "Allowing error status code: ${vPREV_CURL_ERR_STATUS_CODE} with message: ${vPREV_CURL_ERR_MESSAGE}"
  fi
}

cmd.app._remove_app_from_code_workspace() {
  local tmp_vscode_workspace_file="$1"
  jq 'del(.folders[] | select(.name == "App.'"${vPROJECT_APP}"'"))' "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
  if ! jq . "${tmp_vscode_workspace_file}.tmp" >/dev/null; then
    log_error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}.tmp"
    exit 1
  fi
  mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
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
  local tmp_app_dir="$(mktemp -d)"
  local tmp_misc_dir="$(mktemp -d)"
  local tmp_file="$(mktemp -d)/repo"
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
## This script is executed prior to any command run in the SolOS's shell when in the context of this app.
## Do things like check for dependencies, set environment variables, etc.
##
## Example logic: if an app requires a specific version of Node.js, you could check for it here 
## and then use nvm to switch to it.
##
## Important note: idempotency is YOUR responsibility.
#########################################################################################################

# Write your code below:
echo "Hello from the pre-exec script for app: ${vPROJECT_APP}"
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
  # This gives the best UX in VS Code since a new terminal will automatically assume the app's context.
  cmd.app._remove_app_from_code_workspace "${tmp_vscode_workspace_file}"
  jq \
    --arg app_name "${vPROJECT_APP}" \
    '.folders |= [{ "name": "App.'"${vPROJECT_APP}"'", "uri": "'"${vUSERS_HOME_DIR}"'/.solos/projects/'"${vPROJECT_NAME}"'/apps/'"${vPROJECT_APP}"'", "profile": "solos" }] + .' \
    "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
  mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
  if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
    log_error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
    exit 1
  fi

  chmod +x "${tmp_app_dir}/solos.preexec.sh"
  log_info "${vPROJECT_NAME}:${vPROJECT_APP} - Made the pre-exec script executable."

  # MUST BE DONE LAST SO FAILURES ALONG THE WAY DON'T RESULT IN A PARTIAL APP DIR
  mv "${tmp_app_dir}" "${app_dir}"
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  rm -rf "${tmp_misc_dir}"
  log_info "${vPROJECT_NAME}:${vPROJECT_APP} - Initialized the app."
}

cmd.app() {
  solos.use_checked_out_project
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
    local project_id="$(lib.utils.generate_project_id)"
    local tmp_project_ssh_dir="$(mktemp -d)"
    if [[ ! -d ${tmp_project_ssh_dir} ]]; then
      log_error "Unexpected error: no tmp dir was created."
      exit 1
    fi
    lib.ssh.project_build_keypair "${tmp_project_ssh_dir}" || exit 1
    log_info "${vPROJECT_NAME} - Created keypair for project"
    lib.ssh.project_give_keyfiles_permissions "${tmp_project_ssh_dir}" || exit 1
    log_info "${vPROJECT_NAME} - Set permissions on keypair for project"
    mkdir -p "${HOME}/.solos/projects/${vPROJECT_NAME}"
    cp -a "${tmp_project_ssh_dir}" "${HOME}/.solos/projects/${vPROJECT_NAME}/.ssh"
    echo "${project_id}" >"${HOME}/.solos/projects/${vPROJECT_NAME}/id"
    log_info "${vPROJECT_NAME} - Established project directory"
  fi
  # We should be able to re-run the checkout command and pick up where we left
  # off if we didn't supply all the variables the first time.
  solos.prompts
  lib.global_store.set "checked_out_project" "${vPROJECT_NAME}"
  local vscode_dir="${HOME}/.solos/projects/${vPROJECT_NAME}/.vscode"
  mkdir -p "${vscode_dir}"
  local tmp_dir="$(mktemp -d)"
  cp "${HOME}/.solos/src/container/launchfiles/solos.code-workspace" "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"
  if lib.utils.template_variables "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace"; then
    cp -f "${tmp_dir}/solos-${vPROJECT_NAME}.code-workspace" "${vscode_dir}/solos-${vPROJECT_NAME}.code-workspace"
    log_info "${vPROJECT_NAME} - Successfully templated the Visual Studio Code workspace file."
  else
    log_error "${vPROJECT_NAME} - Failed to build the code workspace file."
    exit 1
  fi
  log_info "${vPROJECT_NAME} - Checkout out."
}
cmd.try() {
  solos.use_checked_out_project
  log_warn "TODO: implementation needed"
}
# The main user-facing options should get implemented here.
solos.ingest_opts() {
  for i in "${!vOPTIONS[@]}"; do
    case "${vOPTIONS[$i]}" in
    argv1=*)
      if [[ ${vCMD} = "app" ]] || [[ ${vCMD} = "checkout" ]]; then
        vPROJECT_APP="${vOPTIONS[$i]#*=}"
      fi
      ;;
    esac
  done
}
solos.prune_nonexistent_apps() {
  local tmp_dir="$(mktemp -d)"
  local vscode_workspace_file="${HOME}/.solos/projects/${vPROJECT_NAME}/.vscode/solos-${vPROJECT_NAME}.code-workspace"
  if [[ ! -f ${vscode_workspace_file} ]]; then
    log_error "Unexpected error: no code workspace file: ${vscode_workspace_file}"
    exit 1
  fi
  local tmp_vscode_workspace_file="${tmp_dir}/$(basename ${vscode_workspace_file})"
  cp -f "${vscode_workspace_file}" "${tmp_vscode_workspace_file}"
  local apps="$(jq '.folders[] | select(.name | startswith("App."))' "${tmp_vscode_workspace_file}" | grep -Po '"name": "\K[^"]*' | cut -d'.' -f2)"
  local nonexistent_apps=()
  while read -r app; do
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
# Ensure the user doesn't have to supply the --project flag every time.
solos.use_checked_out_project() {
  vPROJECT_NAME="$(global_store.get "checked_out_project")"
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "No project currently checked out."
    exit 1
  fi
  vPROJECT_ID="$(utils.get_project_id)"
  if [[ -z ${vPROJECT_ID} ]]; then
    log_error "Unexpected error: no project ID found for ${vPROJECT_NAME}."
    exit 1
  fi
}
solos.require_provisioned_s3() {
  local s3_object_store="$(project_secrets.get "s3_object_store")"
  local s3_access_key="$(project_secrets.get "s3_access_key")"
  local s3_secret="$(project_secrets.get "s3_secret")"
  local s3_host="$(project_secrets.get "s3_host")"
  if [[ -z ${s3_object_store} ]]; then
    log_error "No s3_object_store found. Please provision s3 storage. See \`solos --help\` for more information."
    exit 1
  fi
  if [[ -z ${s3_access_key} ]]; then
    log_error "No s3_access_key found. Please provision s3 storage. See \`solos --help\` for more information."
    exit 1
  fi
  if [[ -z ${s3_secret} ]]; then
    log_error "No s3_secret found. Please provision s3 storage. See \`solos --help\` for more information."
    exit 1
  fi
  if [[ -z ${s3_host} ]]; then
    log_error "No s3_host found. Please provision s3 storage. See \`solos --help\` for more information."
    exit 1
  fi
}

# Parses CLI arguments into simpler data structures and validates against
# the usage strings in args/usage.sh.
argparse.requirements
argparse.cmd "$@"
argparse.validate_opts

if [[ -z ${vCMD} ]]; then
  exit 1
fi
if ! command -v "cmd.${vCMD}" &>/dev/null; then
  log_error "No implementation for ${vCMD} exists."
  exit 1
fi
solos.ingest_opts
"cmd.${vCMD}" || true
if [[ -n ${vPROJECT_NAME} ]]; then
  if ! solos.prune_nonexistent_apps; then
    log_error "Unexpected error: something failed while pruning nonexistent apps from the vscode workspace file."
  fi
fi
