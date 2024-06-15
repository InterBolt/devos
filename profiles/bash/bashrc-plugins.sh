#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/shared/log.sh" || exit 1
. "${HOME}/.solos/src/shared/gum.sh" || exit 1

bashrc_plugins__dir="${HOME}/.solos/plugins"
bashrc_plugins__manifest_file="${bashrc_plugins__dir}/solos.manifest.json"

bashrc_plugins.print_help() {
  cat <<EOF

USAGE: plugins <add|remove|list>

DESCRIPTION:

Some utility commands to add or remove plugins from the SolOS. \
Waits for the current set of plugins to finish running before adding or removing a plugin.

When adding plugins, a <name> and optional <url> are expected. If a <url> is not provided, \
we'll assume you're creating a local plugin. Local plugins are initialized with a directory and \
a modification to the project's code-workspace file.

Only plugins with an associated remote url can be removed. Attempting to remove a local plugin will result in \
a print out of manual instructions.
EOF
}
bashrc_plugins.get_dirnames() {
  local tmp_file="$(mktemp)"
  if ! find "${bashrc_plugins__dir}" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; >"${tmp_file}"; then
    echo "SOLOS:EXIT:1"
    return 1
  fi
  cat "${tmp_file}" | xargs
}
bashrc_plugins.main() {
  if [[ $# -eq 0 ]]; then
    bashrc_plugins.print_help
    return 0
  fi
  if bashrc.is_help_cmd "$1"; then
    bashrc_plugins.print_help
    return 0
  fi
  local curr_plugin_dirnames="$(bashrc_plugins.get_dirnames)"
  if [[ ${curr_plugin_dirnames} = "SOLOS:EXIT:1" ]]; then
    log.error "Failed to get the current plugin directories."
    return 1
  fi
  curr_plugin_dirnames=($(curr_plugin_dirnames))
  local arg_cmd="${1}"
  local arg_plugin_name="${2}"
  if [[ -z ${arg_plugin_name} ]]; then
    log.error "Command is required."
    return 1
  fi
  if [[ ${arg_cmd} = "add" ]]; then
    local plugin_url="${3:-""}"
    for plugin_dirname in "${curr_plugin_dirnames[@]}"; do
      if [[ ${plugin_dirname} = ${arg_plugin_name} ]]; then
        log.error "Plugin with the name: ${arg_plugin_name} already exists."
        return 1
      fi
    done
    if [[ -z ${plugin_url} ]]; then
      log.info "Creating a local plugin."
      local checked_out_project="$(lib.checked_out_project)"
      local code_workspace_file="${HOME}/.solos/projects/${checked_out_project}/.vscode/${checked_out_project}.code-workspace"
      if [[ ! -f ${code_workspace_file} ]]; then
        log.error "Code workspace file not found at: ${code_workspace_file}"
        return 1
      fi
      local plugin_path="${bashrc_plugins__dir}/${arg_plugin_name}"
      local tmp_plugin_dir="$(mktemp -d)"
      if ! mkdir "${plugin_path}"; then
        log.error "Failed to create plugin directory at: ${plugin_path}"
        return 1
      fi
      local tmp_code_workspace_file="$(mktemp)"
      jq \
        --arg app_name "${arg_plugin_name}" \
        '.folders |= [{ "name": "plugin.'"${arg_plugin_name}"'", "uri": "'"${plugin_path}"'", "profile": "shell" }] + .' \
        "${code_workspace_file}" \
        >"${tmp_code_workspace_file}"
      local precheck_plugin_path="${HOME}/.solos/src/plugins/precheck.sh"
      if ! cp "${precheck_plugin_path}" "${tmp_plugin_dir}/plugin"; then
        log.error "Failed to copy the precheck plugin to the plugin directory."
        rm -rf "${plugin_path}"
        return 1
      fi
      if ! chmod +x "${tmp_plugin_dir}/plugin"; then
        log.error "Failed to make the plugin executable."
        rm -rf "${plugin_path}"
        return 1
      fi
      # Do the operations.
      cp "${tmp_plugin_dir}/" "${plugin_path}/"
      mv "${tmp_code_workspace_file}" "${code_workspace_file}"
      log.info "Reloading the daemon with the new the ${arg_plugin_name} plugin (with default precheck template)."
      local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
      tmp_stderr="$(mktemp)"
      if ! daemon "reload" >/dev/null 2>"${tmp_stderr}"; then
        cat "${tmp_stderr}"
        return 1
      fi
      log.info "Successfully added the plugin: ${arg_plugin_name}"
      cat <<EOF
INSTRUCTIONS:
${full_line}
1. Review the plugin script at ${plugin_path}/plugin to understand how each plugin phase works. \
This script is a copy of the default precheck plugin, which runs in between any two plugin lifecycles.
2. Modify it or overwrite it with your own script.
3. Review your new plugin's logs with \`daemon tail -f\`
${full_line}
EOF
    elif [[ ! ${plugin_url} =~ ^http ]]; then
      log.error "Must be a valid http url: ${plugin_url}"
      return 1
    else
      local tmp_stderr="$(mktemp)"
      log.info "Waiting for the daemon to complete its current set of plugins."
      if ! daemon "kill" >/dev/null 2>"${tmp_stderr}"; then
        cat "${tmp_stderr}"
        return 1
      fi
      local tmp_manifest_file="$(mktemp)"
      jq ". += [{\"name\": \"${arg_plugin_name}\", \"source\": \"${plugin_url}\"}]" "${bashrc_plugins__manifest_file}" >"${tmp_manifest_file}"
      mv "${tmp_manifest_file}" "${bashrc_plugins__manifest_file}"
      log.info "Added source url to manifest at: ${bashrc_plugins__manifest_file}"
      log.info "Reloading the daemon. Will download the plugin on its next run."
      tmp_stderr="$(mktemp)"
      if ! daemon "reload" >/dev/null 2>"${tmp_stderr}"; then
        cat "${tmp_stderr}"
        return 1
      fi
      log.info "Successfully added the plugin: ${arg_plugin_name}"
      log.info "TIP: Verify everything is working with: \`daemon tail -f\`"
    fi
  fi
  if [[ ${arg_cmd} = "remove" ]]; then
    if [[ -z ${arg_plugin_name} ]]; then
      log.error "Plugin name is required."
      return 1
    fi
    if [[ ! -d "${bashrc_plugins__dir}/${arg_plugin_name}" ]]; then
      log.error "Plugin: ${arg_plugin_name} not found in the plugin directory: ${bashrc_plugins__dir}"
      return 1
    fi
    local plugin_names=($(jq -r '.[].name' <<<"${bashrc_plugins__manifest_file}"))
    local plugin_sources=($(jq -r '.[].source' <<<"${bashrc_plugins__manifest_file}"))
    local plugin_found_in_manifest=false
    local plugin_is_local=false
    for plugin_name in "${plugin_names[@]}"; do
      if [[ ${plugin_name} = ${arg_plugin_name} ]]; then
        plugin_found_in_manifest=true
        if [[ -d "${bashrc_plugins__dir}/${plugin_name}" ]]; then
          plugin_is_local=true
        fi
        break
      fi
    done
    if [[ ${plugin_is_local} = false ]]; then
      log.warn "Plugin: ${arg_plugin_name} is not a remote plugin. Manual action required:"
      local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
      cat <<EOF
INSTRUCTIONS:
${full_line}
1. Kill the daemon: \`daemon kill\`
2. Remove the plugin from the manifest file: ${bashrc_plugins__manifest_file}
3. Remove the plugin directory: ${bashrc_plugins__dir}/${arg_plugin_name}
4. Reload the daemon: \`daemon reload\`
${full_line}
EOF
      return 0
    fi
    if [[ ${plugin_found_in_manifest} = false ]]; then
      log.error "Plugin: ${arg_plugin_name} not found in the manifest file: ${bashrc_plugins__manifest_file} or at ${bashrc_plugins__dir}."
      return 1
    fi
    log.info "Waiting for the daemon to complete its current set of plugins."
    local tmp_stderr="$(mktemp)"
    if ! daemon "kill" >/dev/null 2>"${tmp_stderr}"; then
      cat "${tmp_stderr}"
      return 1
    fi
    local tmp_manifest_file="$(mktemp)"
    jq "map(select(.name != \"${arg_plugin_name}\"))" "${bashrc_plugins__manifest_file}" >"${tmp_manifest_file}"
    mv "${tmp_manifest_file}" "${bashrc_plugins__manifest_file}"
    log.info "Removed source reference from manifest at: ${bashrc_plugins__manifest_file}"
    rm -rf "${bashrc_plugins__dir}/${arg_plugin_name}"
    log.warn "Deleted plugin directory: ${bashrc_plugins__dir}/${arg_plugin_name} and reloading the daemon."
    tmp_stderr="$(mktemp)"
    if ! daemon "reload" >/dev/null 2>"${tmp_stderr}"; then
      cat "${tmp_stderr}"
      return 1
    fi
    return 0
  fi
  log.error "Unknown command: ${arg_cmd}"
  return 1
}
