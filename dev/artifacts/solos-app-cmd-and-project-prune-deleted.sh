#!/usr/bin/env bash

bin.cmd.app._remove_app_from_code_workspace() {
  local workspace_file="$1"
  jq 'del(.folders[] | select(.name == "'"${container__project}"'.'"${container__project_app}"'"))' "${workspace_file}" >"${workspace_file}.tmp"
  if ! jq . "${workspace_file}.tmp" >/dev/null; then
    log.error "Failed to validate the updated code workspace file: ${workspace_file}.tmp"
    exit 1
  fi
  mv "${workspace_file}.tmp" "${workspace_file}"
}
bin.cmd.app._get_path_to_app() {
  local path_to_apps="${HOME}/.solos/projects/${container__project}/apps"
  mkdir -p "${path_to_apps}"
  echo "${path_to_apps}/${container__project_app}"
}
bin.cmd.app._init() {
  if [[ ! ${container__project_app} =~ ^[a-z_-]*$ ]]; then
    log.error "Invalid app name. App names must be lowercase and can only contain letters, hyphens, and underscores."
    exit 1
  fi
  # Do this to prevent when the case where the user wants to create an app but has the wrong
  # project checked out. They can still fuck it up but at least we provide some guardrail.
  local should_continue="$(gum.confirm_new_app "${container__project}" "${container__project_app}")"
  if [[ ${should_continue} = false ]]; then
    log.error "${container__project}:${container__project_app} - Aborted."
    exit 1
  fi
  local tmp_app_dir="$(mktemp -d -q)"
  local tmp_misc_dir="$(mktemp -d -q)"
  local tmp_file="$(mktemp -d -q)/repo"
  if ! gum.repo_url >"${tmp_file}"; then
    log.error "${container__project}:${container__project_app} - Aborted."
    exit 1
  fi
  local repo_url="$(cat "${tmp_file}")"
  if [[ -n ${repo_url} ]]; then
    if ! git clone "$(cat ${tmp_file})" "${tmp_app_dir}" >/dev/null; then
      log.error "Failed to clone the app's repository."
      exit 1
    fi
    log.info "${container__project}:${container__project_app} - Cloned the app's repository."
  else
    log.warn "${container__project}:${container__project_app} - No repo url supplied. Creating an empty app directory."
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
echo "Hello from the pre-exec script for app: ${container__project_app}"
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
echo "Hello from the post-exec script for app: ${container__project_app}"
EOF
  log.info "${container__project}:${container__project_app} - Created the pre-exec script."
  local app_dir="$(bin.cmd.app._get_path_to_app)"
  local vscode_workspace_file="${HOME}/.solos/projects/${container__project}/.vscode/${container__project}.code-workspace"
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
    --arg app_name "${container__project_app}" \
    '.folders |= [{ "name": "app.'"${container__project_app}"'", "uri": "'"${container__users_home_dir}"'/.solos/projects/'"${container__project}"'/apps/'"${container__project_app}"'", "profile": "shell" }] + .' \
    "${tmp_vscode_workspace_file}" >"${tmp_vscode_workspace_file}.tmp"
  mv "${tmp_vscode_workspace_file}.tmp" "${tmp_vscode_workspace_file}"
  if ! jq . "${tmp_vscode_workspace_file}" >/dev/null; then
    log.error "Failed to validate the updated code workspace file: ${tmp_vscode_workspace_file}"
    exit 1
  fi

  chmod +x "${tmp_app_dir}/solos.preexec.sh"
  chmod +x "${tmp_app_dir}/solos.postexec.sh"
  log.info "${container__project}:${container__project_app} - Made the lifecycle scripts executable."

  # Do last to prevent partial app setup.
  mv "${tmp_app_dir}" "${app_dir}"
  cp -f "${tmp_vscode_workspace_file}" "${vscode_workspace_file}"
  rm -rf "${tmp_misc_dir}"
  log.info "${container__project}:${container__project_app} - Initialized the app."
}
bin.cmd.app() {
  container__project="$(container.store_get "checked_out_project")"
  if [[ -z ${container__project} ]]; then
    log.error "No project currently checked out."
    exit 1
  fi
  if [[ -z "${container__project_app}" ]]; then
    log.error "No app name was supplied."
    exit 1
  fi
  if [[ -z "${container__project}" ]]; then
    log.error "A project name is required. Please checkout a project first."
    exit 1
  fi
  local app_dir="$(bin.cmd.app._get_path_to_app)"
  if [[ ! -d ${app_dir} ]]; then
    bin.cmd.app._init
  else
    log.info "${container__project}:${container__project_app} - App already exists."
  fi
}

bin.project.prune() {
  local tmp_dir="$(mktemp -d -q)"
  local vscode_workspace_file="${HOME}/.solos/projects/${container__project}/.vscode/${container__project}.code-workspace"
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
    local app_dir="${HOME}/.solos/projects/${container__project}/apps/${app}"
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
