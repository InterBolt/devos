#!/usr/bin/env bash

set -o errexit

cd "$(dirname "${BASH_SOURCE[0]}")"

vSOLOS_RUNTIME=1
vSOLOS_BIN_DIR="$(pwd)"

# Will include dotfiles in globbing.
shopt -s dotglob

# Slots to store returns/responses. Bash don't allow rich return
# types, so we do dis hack shite instead.
vPREV_CURL_RESPONSE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_ERR_MESSAGE=""
vPREV_RETURN=()
vPREV_NEXT_ARGS=()

. "${HOME}/.solos/src/bin/shared/flag-parser.sh"

shared.flag_parser.run \
  --restricted-developer \
  --restricted-noop \
  "ARGS:" "$@"
set -- "${vPREV_NEXT_ARGS[@]}" || exit 1
vRESTRICTED_MODE_DEVELOPER=${vPREV_RETURN[0]:-false}
vRESTRICTED_MODE_NOOP=${vPREV_RETURN[1]:-false}
if [[ ${vRESTRICTED_MODE_NOOP} = true ]]; then
  exit 0
fi

. "${HOME}/.solos/src/pkgs/gum.sh"
. "${HOME}/.solos/src/log.sh"

. "${HOME}/.solos/src/bin/cli/usage.sh"
. "${HOME}/.solos/src/bin/cli/parse.sh"
. "${HOME}/.solos/src/bin/lib/docker.sh"
. "${HOME}/.solos/src/bin/lib/store.sh"
. "${HOME}/.solos/src/bin/lib/ssh.sh"
. "${HOME}/.solos/src/bin/lib/utils.sh"
. "${HOME}/.solos/src/bin/cmd/app.sh"
. "${HOME}/.solos/src/bin/cmd/backup.sh"
. "${HOME}/.solos/src/bin/cmd/checkout.sh"
. "${HOME}/.solos/src/bin/cmd/health.sh"
. "${HOME}/.solos/src/bin/cmd/provision.sh"
. "${HOME}/.solos/src/bin/cmd/restore.sh"
. "${HOME}/.solos/src/bin/cmd/teardown.sh"
. "${HOME}/.solos/src/bin/cmd/try.sh"

# The directory path of the user's home directory.
# Everything here runs in docker so this is the only way I
# know to get the user's home directory.
# TODO: is there a more standard way to get the user's home directory within
# TODO[c]: a docker container?
vUSERS_HOME_DIR="$(lib.store.global.get "users_home_dir" "/root")"
# Populated by the CLI parsing functions.
vCLI_CMD=""
vCLI_OPTIONS=()
# Everything we need to operate our "project"
vPROJECT_OPENAI_API_KEY=""
vPROJECT_PROVIDER_API_KEY=""
vPROJECT_PROVIDER_NAME=""
vPROJECT_ROOT_DOMAIN=""
vPROJECT_SEED_SECRET=""
vPROJECT_IP=""
vPROJECT_NAME=""
vPROJECT_APP=""
vPROJECT_ID=""
vPROJECT_S3_HOST=""
vPROJECT_S3_OBJECT_STORE=""
vPROJECT_S3_ACCESS_KEY=""
vPROJECT_S3_SECRET=""

# The main user-facing options should get implemented here.
solos.ingest_main_options() {
  for i in "${!vCLI_OPTIONS[@]}"; do
    case "${vCLI_OPTIONS[$i]}" in
    argv1=*)
      if [[ ${vCLI_CMD} = "app" ]]; then
        vPROJECT_APP="${vCLI_OPTIONS[$i]#*=}"
      fi
      ;;
    project=*)
      if [[ ${vCLI_CMD} != "checkout" ]]; then
        log_error "The --project flag is only valid for the 'checkout' command."
        exit 1
      fi
      val="${vCLI_OPTIONS[$i]#*=}"
      if [[ ! "${val}" =~ ^[a-z_-]*$ ]]; then
        log_error 'Invalid project name: '"${val}"'. Can only contain lowercase letters, underscores, and hyphens.'
        exit 1
      fi
      vPROJECT_NAME="${val}"
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
solos.prompts() {
  # Automatically generate a secret if one doesn't exist.
  vPROJECT_SEED_SECRET="$(lib.store.project.set_on_empty "secret" "$(lib.utils.generate_secret)")"
  # Prompts
  vPROJECT_PROVIDER_NAME="$(lib.store.project.prompt "provider_name" 'Only "vultr" is supported at this time.')"
  local path_to_provision_implementation="${vSOLOS_BIN_DIR}/provision/${vPROJECT_PROVIDER_NAME}.sh"
  if [[ ! -f ${path_to_provision_implementation} ]]; then
    log_error "Unknown provider: ${path_to_provision_implementation}. See the 'provision' directory for supported providers."
    lib.store.project.del "provider_name"
    solos.prompts
  fi
  vPROJECT_ROOT_DOMAIN="$(lib.store.project.prompt "root_domain")"
  if [[ ! "${vPROJECT_ROOT_DOMAIN}" =~ \.[a-z]+$ ]]; then
    log_error "Invalid root domain: ${vPROJECT_ROOT_DOMAIN}."
    lib.store.project.del "root_domain"
    solos.prompts
  fi
  vPROJECT_PROVIDER_API_KEY="$(lib.store.project.prompt "provider_api_key" 'Use your provider dashboard to create an API key.')"
  vPROJECT_OPENAI_API_KEY="$(lib.store.project.prompt "openai_api_key" 'Use the OpenAI dashboard to create an API key.')"
  # Try to grab things from project store
  vPROJECT_S3_OBJECT_STORE="$(lib.store.project.get "s3_object_store")"
  vPROJECT_S3_ACCESS_KEY="$(lib.store.project.get "s3_access_key")"
  vPROJECT_S3_SECRET="$(lib.store.project.get "s3_secret")"
  vPROJECT_S3_HOST="$(lib.store.project.get "s3_host")"
}
# Ensure the user doesn't have to supply the --project flag every time.
solos.use_checked_out_project() {
  vPROJECT_NAME="$(lib.store.global.get "checked_out_project")"
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "No project currently checked out."
    exit 1
  fi
  vPROJECT_ID="$(lib.utils.get_project_id)"
  if [[ -z ${vPROJECT_ID} ]]; then
    log_error "Unexpected error: no project ID found for ${vPROJECT_NAME}."
    exit 1
  fi
  vPROJECT_IP="$(lib.ssh.project_extract_project_ip)"
}

if [[ ${vRESTRICTED_MODE_DEVELOPER} = true ]]; then
  lib.utils.validate_interfaces \
    "${vSOLOS_BIN_DIR}/provision" \
    __interface__.txt
fi

# Parses CLI arguments into simpler data structures and validates against
# the usage strings in cli/usage.sh.
cli.parse.requirements
cli.parse.cmd "$@"
cli.parse.validate_opts

if [[ -z ${vCLI_CMD} ]]; then
  exit 1
fi

if ! command -v "cmd.${vCLI_CMD}" &>/dev/null; then
  log_error "No implementation for ${vCLI_CMD} exists."
  exit 1
fi

# Assign the cli flag options to some of our global variables.
# Seperate "main" from "test" options to not overwhelm the user
# facing implementation.
solos.ingest_main_options
if [[ ${vCLI_CMD} = "test" ]]; then
  solos.ingest_test_options
fi

"cmd.${vCLI_CMD}" || true
if [[ -n ${vPROJECT_NAME} ]]; then
  if ! solos.prune_nonexistent_apps; then
    log_error "Unexpected error: something failed while pruning nonexistent apps from the vscode workspace file."
  fi
fi
