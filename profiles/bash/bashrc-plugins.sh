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
  if [[ ${1} = "add" ]]; then
    local plugin_name="${2}"
    local plugin_url="${3:-""}"
    if [[ -z ${plugin_name} ]]; then
      log.error "Plugin name is required."
      return 1
    fi
    for plugin_dirname in "${curr_plugin_dirnames[@]}"; do
      if [[ ${plugin_dirname} = ${plugin_name} ]]; then
        log.error "Plugin with the name: ${plugin_name} already exists."
        return 1
      fi
    done
    if [[ -z ${plugin_url} ]]; then
      log.info "Creating a local plugin."
      # TODO: Create a local plugin.
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
      jq ". += [{\"name\": \"${plugin_name}\", \"source\": \"${plugin_url}\"}]" "${bashrc_plugins__manifest_file}" >"${tmp_manifest_file}"
      mv "${tmp_manifest_file}" "${bashrc_plugins__manifest_file}"
      log.info "Added remote executable to manifest at: ${bashrc_plugins__manifest_file}"
      log.info "Reloading the daemon. Will pick up the new plugin on the next run."
      tmp_stderr="$(mktemp)"
      if ! daemon "reload" >/dev/null 2>"${tmp_stderr}"; then
        cat "${tmp_stderr}"
        return 1
      fi
      log.info "Successfully added the plugin: ${plugin_name}"
      log.info "Monitor daemon logs to verify everything is working with: \`daemon tail -f\`"
    fi
  fi
  if [[ ${1} = "remove" ]]; then
    local plugin_names=($(jq -r '.[].name' <<<"${bashrc_plugins__manifest_file}"))
    local plugin_sources=($(jq -r '.[].source' <<<"${bashrc_plugins__manifest_file}"))
    local plugin_found_in_manifest=false
    local plugin_is_local=false
    for plugin_name in "${plugin_names[@]}"; do
      if [[ ${plugin_name} = ${2} ]]; then
        plugin_found_in_manifest=true
        if [[ -d "${bashrc_plugins__dir}/${plugin_name}" ]]; then
          plugin_is_local=true
        fi
        break
      fi
    done
    if [[ ${plugin_is_local} = false ]]; then
      log.warn "Plugin: ${2} is not a remote plugin. Manual action required:"
      local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
      cat <<EOF
INSTRUCTIONS:
${full_line}
1. Kill the daemon: \`daemon kill\`
2. Remove the plugin from the manifest file: ${bashrc_plugins__manifest_file}
3. Remove the plugin directory: ${bashrc_plugins__dir}/${2}
4. Reload the daemon: \`daemon reload\`
${full_line}
EOF
      return 0
    fi
    if [[ ${plugin_found_in_manifest} = false ]]; then
      log.error "Plugin: ${2} not found in the manifest file: ${bashrc_plugins__manifest_file} or at ${bashrc_plugins__dir}."
      return 1
    fi
    log.info "Waiting for the daemon to complete its current set of plugins."
    local tmp_stderr="$(mktemp)"
    if ! daemon "kill" >/dev/null 2>"${tmp_stderr}"; then
      cat "${tmp_stderr}"
      return 1
    fi
    local tmp_manifest_file="$(mktemp)"
    jq "map(select(.name != \"${2}\"))" "${bashrc_plugins__manifest_file}" >"${tmp_manifest_file}"
    mv "${tmp_manifest_file}" "${bashrc_plugins__manifest_file}"
    log.info "Removed remote executable from manifest at: ${bashrc_plugins__manifest_file}"
    log.info "Reloading the daemon. Will pick up the new plugin on the next run."
    tmp_stderr="$(mktemp)"
    if ! daemon "reload" >/dev/null 2>"${tmp_stderr}"; then
      cat "${tmp_stderr}"
      return 1
    fi
    return 0
  fi
  log.error "Unknown command: ${1}"
  return 1
}
