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

. "${HOME}/.solos/src/cli/misc/flag-parser.sh"

misc.flag_parser.run \
  --restricted-noop \
  "ARGS:" "$@"
set -- "${vPREV_NEXT_ARGS[@]}" || exit 1
vRESTRICTED_MODE_NOOP=${vPREV_RETURN[0]:-false}
if [[ ${vRESTRICTED_MODE_NOOP} = true ]]; then
  exit 0
fi

. "${HOME}/.solos/src/pkgs/gum.sh"
. "${HOME}/.solos/src/log.sh"

. "${HOME}/.solos/src/cli/args/usage.sh"
. "${HOME}/.solos/src/cli/args/parse.sh"
. "${HOME}/.solos/src/cli/provisioners/vultr.sh"
. "${HOME}/.solos/src/cli/libs/store.sh"
. "${HOME}/.solos/src/cli/libs/secrets.sh"
. "${HOME}/.solos/src/cli/libs/ssh.sh"
. "${HOME}/.solos/src/cli/libs/utils.sh"
. "${HOME}/.solos/src/cli/cmds/app.sh"
. "${HOME}/.solos/src/cli/cmds/backup.sh"
. "${HOME}/.solos/src/cli/cmds/checkout.sh"
. "${HOME}/.solos/src/cli/cmds/health.sh"
. "${HOME}/.solos/src/cli/cmds/restore.sh"
. "${HOME}/.solos/src/cli/cmds/teardown.sh"
. "${HOME}/.solos/src/cli/cmds/try.sh"

# The directory path of the user's home directory.
# Everything here runs in docker so this is the only way I
# know to get the user's home directory.
# TODO: is there a more standard way to get the user's home directory within
# TODO[c]: a docker container?
vUSERS_HOME_DIR="$(lib.global_store.get "users_home_dir" "/root")"
# Populated by the CLI parsing functions.
vCLI_CMD=""
vCLI_OPTIONS=()
# Basic project info.
# Most other things are stored in the project's secrets or store.
vPROJECT_NAME=""
vPROJECT_APP=""
vPROJECT_ID=""

# The main user-facing options should get implemented here.
solos.ingest_opts() {
  for i in "${!vCLI_OPTIONS[@]}"; do
    case "${vCLI_OPTIONS[$i]}" in
    argv1=*)
      if [[ ${vCLI_CMD} = "app" ]] || [[ ${vCLI_CMD} = "checkout" ]]; then
        vPROJECT_APP="${vCLI_OPTIONS[$i]#*=}"
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
  vPROJECT_NAME="$(lib.global_store.get "checked_out_project")"
  if [[ -z ${vPROJECT_NAME} ]]; then
    log_error "No project currently checked out."
    exit 1
  fi
  vPROJECT_ID="$(lib.utils.get_project_id)"
  if [[ -z ${vPROJECT_ID} ]]; then
    log_error "Unexpected error: no project ID found for ${vPROJECT_NAME}."
    exit 1
  fi
}
solos.require_provisioned_s3() {
  local s3_object_store="$(lib.project_secrets.get "s3_object_store")"
  local s3_access_key="$(lib.project_secrets.get "s3_access_key")"
  local s3_secret="$(lib.project_secrets.get "s3_secret")"
  local s3_host="$(lib.project_secrets.get "s3_host")"
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
solos.ingest_opts
"cmd.${vCLI_CMD}" || true
if [[ -n ${vPROJECT_NAME} ]]; then
  if ! solos.prune_nonexistent_apps; then
    log_error "Unexpected error: something failed while pruning nonexistent apps from the vscode workspace file."
  fi
fi
