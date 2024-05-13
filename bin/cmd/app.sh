#!/usr/bin/env bash

cmd.app._get_path_to_app() {
  local path_to_apps="${HOME}/.solos/projects/${vPROJECT_NAME}/apps"
  mkdir -p "${path_to_apps}"
  echo "${path_to_apps}/${vPROJECT_APP}"
}

cmd.app._init() {
  if [[ ! ${vPROJECT_APP} =~ ^[a-z_-]*$ ]]; then
    log.error "Invalid app name. App names must be lowercase and can only contain letters, hyphens, and underscores."
    exit 1
  fi
  # Do this to prevent when the case where the user wants to create an app but has the wrong
  # project checked out. They can still fuck it up but at least we provide some guardrail.
  local should_continue="$(pkg.gum.confirm_new_app "${vPROJECT_NAME}" "${vPROJECT_APP}")"
  if [[ ${should_continue} = false ]]; then
    log.error "${vPROJECT_NAME}:${vPROJECT_APP} - Aborted."
    exit 1
  fi
  local tmp_app_dir="$(mktemp -d)"
  local tmp_misc_dir="$(mktemp -d)"
  local tmp_file="$(mktemp -d)/repo"
  if ! pkg.gum.repo_url >"${tmp_file}"; then
    log.error "${vPROJECT_NAME}:${vPROJECT_APP} - Aborted."
    exit 1
  fi
  local repo_url="$(cat "${tmp_file}")"
  if [[ -n ${repo_url} ]]; then
    if ! git clone "$(cat ${tmp_file})" "${tmp_app_dir}" >/dev/null; then
      log.error "Failed to clone the app's repository."
      exit 1
    fi
    log.info "${vPROJECT_NAME}:${vPROJECT_APP} - Cloned the app's repository."
  else
    log.warn "${vPROJECT_NAME}:${vPROJECT_APP} - No repo url supplied. Creating an empty app directory."
  fi
  cat <<EOF >"${tmp_app_dir}/solos.preexec.sh"
#!/usr/bin/env bash

# Type \`man\` in your SolOS shell to see a list of commands available to you.
. "${HOME}/.solos/.bashrc" --source-only || exit 1

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
  log.info "${vPROJECT_NAME}:${vPROJECT_APP} - Created the pre-exec script."
  local app_dir="$(cmd.app._get_path_to_app)"
  local vscode_workspace_file="${HOME}/.solos/projects/${vPROJECT_NAME}/.vscode/solos-${vPROJECT_NAME}.code-workspace"
  local tmp_vscode_workspace_file="${tmp_misc_dir}/$(basename ${vscode_workspace_file})"
  if [[ ! -f "${vscode_workspace_file}" ]]; then
    log.error "Unexpected error: no code workspace file: ${vscode_workspace_file}"
    exit 1
  fi
  cp -f "${vscode_workspace_file}" "${tmp_vscode_workspace_file}"

  # if the app already exists in the workspace file in the folders array with the pattern App.<app_name>, then we're good.
  if ! jq '.folders[] | select(.name | startswith("App."))' "${tmp_vscode_workspace_file}" | grep -q "${vPROJECT_APP}"; then
    jq \
      --arg app_name "${vPROJECT_APP}" \
      '.folders += [{ "name": "App.'"${vPROJECT_APP}"'", "uri": "'"${vUSERS_HOME_DIR}"'/.solos/projects/'"${vPROJECT_NAME}"'/apps/'"${vPROJECT_APP}"'", "profile": "solos" }]' \
      "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
    mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
    if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
      log.error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
      exit 1
    fi
  else
    log.warn "${vPROJECT_NAME}:${vPROJECT_APP} - App already exists in the code workspace file."
  fi

  chmod +x "${tmp_app_dir}/solos.preexec.sh"
  log.info "${vPROJECT_NAME}:${vPROJECT_APP} - Made the pre-exec script executable."

  # MUST BE DONE LAST SO FAILURES ALONG THE WAY DON'T RESULT IN A PARTIAL APP DIR
  mv "${tmp_app_dir}" "${app_dir}"
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  rm -rf "${tmp_misc_dir}"
  log.info "${vPROJECT_NAME}:${vPROJECT_APP} - Initialized the app."
}

cmd.app() {
  solos.use_checked_out_project
  if [[ -z "${vPROJECT_APP}" ]]; then
    log.error "No app name was supplied."
    exit 1
  fi
  if [[ -z "${vPROJECT_NAME}" ]]; then
    log.error "A project name is required. Please checkout a project first."
    exit 1
  fi
  local app_dir="$(cmd.app._get_path_to_app)"
  if [[ ! -d ${app_dir} ]]; then
    cmd.app._init
  fi
}
