#!/bin/bash

# lib__data_dir="${HOME}/.solos/data"
# lib__store_dir="${lib__data_dir}/store"

# lib.home_dir_path() {
#   local home_dir_path="$(cat "${lib__store_dir}/users_home_dir" 2>/dev/null || echo "" | xargs)"
#   if [[ -z "${home_dir_path}" ]]; then
#     return 1
#   fi
#   echo "${home_dir_path}"
# }
# bin.build_manifest() {
#   local manifest_file="${HOME}/.solos/plugins/manifest.json"
#   local tmp_manifest_file="$(mktemp)"
#   local plugins=($(ls -d ${HOME}/.solos/plugins/* | xargs))
#   for plugin in ${plugins[@]}; do
#     if [[ -d "${plugin}" ]]; then
#       local plugin_config="${plugin}/solos.json"
#       local plugin_name="$(basename ${plugin})"
#       if [[ ! -s ${tmp_manifest_file} ]]; then
#         echo "[]" >"${tmp_manifest_file}"
#       fi
#       local plugin_source="$(jq -r '.source' "${plugin_config}")"
#       jq \
#         --arg plugin_name "${plugin_name}" \
#         --arg plugin_source "${plugin_source}" '. + [{ name: $plugin_name, source: $plugin_source }]' "${tmp_manifest_file}" \
#         >"${tmp_manifest_file}.tmp"
#       mv "${tmp_manifest_file}.tmp" "${tmp_manifest_file}"
#     fi
#   done
#   mv -f "${tmp_manifest_file}" "${manifest_file}"
# }
# bin.fix_invalid_home_paths() {
#   local tmp_manifest_file="$(mktemp)"
#   echo "[]" >"${tmp_manifest_file}"
#   local manifested_plugins=($(echo "$1" | xargs))
#   local corrected_manifested_plugins=()
#   local i=0
#   local home_dir_path="$(lib.home_dir_path)"
#   for manifested_plugin in ${manifested_plugins[@]}; do
#     if [[ $((i % 2)) -eq 1 ]]; then
#       local source="${manifested_plugin}"
#       if [[ ${source} =~ ^/ ]] && [[ ! ${source} =~ ^${home_dir_path} ]]; then
#         corrected_manifested_plugins+=("${home_dir_path}/.solos/plugins${source##*/.solos/plugins}")
#       else
#         corrected_manifested_plugins+=("${source}")
#       fi
#     else
#       local plugin_name="${manifested_plugin}"
#       corrected_manifested_plugins+=("${plugin_name}")
#     fi
#     i=$((i + 1))
#   done
#   i=0
#   for corrected_manifested_plugin in ${corrected_manifested_plugins[@]}; do
#     if [[ $((i % 2)) -eq 1 ]]; then
#       local name="${corrected_manifested_plugins[$((i - 1))]}"
#       local source="${corrected_manifested_plugin}"
#       jq \
#         --arg name "${name}" \
#         --arg source "${source}" '. + [{ name: $name, source: $source }]' "${tmp_manifest_file}" \
#         >"${tmp_manifest_file}.tmp"
#       mv "${tmp_manifest_file}.tmp" "${tmp_manifest_file}"
#     fi
#     i=$((i + 1))
#   done
#   echo "${tmp_manifest_file}"
# }
# bin.add_missing_plugins_to_manifest() {
#   local manifest_file="${HOME}/.solos/plugins/manifest.json"
#   local tmp_manifest_file="$(mktemp)"
#   cp -f "${manifest_file}" "${tmp_manifest_file}"
#   local plugins=($(ls -d ${HOME}/.solos/plugins/* | xargs))
#   for plugin in ${plugins[@]}; do
#     if [[ -d "${plugin}" ]]; then
#       local plugin_config="${plugin}/solos.json"
#       local plugin_name="$(basename ${plugin})"
#       local plugin_source="$(jq -r '.source' "${plugin_config}")"
#       # if we don't find a matching plugin_name, or source in the manifest, add it
#       if ! grep -q "\"name\": \"${plugin_name}\"" "${tmp_manifest_file}" && ! grep -q "\"source\": \"${plugin_source}\"" "${tmp_manifest_file}"; then
#         jq \
#           --arg plugin_name "${plugin_name}" \
#           --arg plugin_source "${plugin_source}" '. + [{ name: $plugin_name, source: $plugin_source }]' "${tmp_manifest_file}" \
#           >"${tmp_manifest_file}.tmp"
#         mv "${tmp_manifest_file}.tmp" "${tmp_manifest_file}"
#       fi
#     fi
#   done
#   echo "${tmp_manifest_file}"
# }
# bin.repair_manifest() {
#   local manifest_file="${HOME}/.solos/plugins/manifest.json"
#   local working_manifest_file="$(mktemp)"
#   if [[ -f "${manifest_file}" ]]; then
#     cp -f "${manifest_file}" "${working_manifest_file}"
#   fi
#   local manifested_plugins=()
#   local found_plugins=()
#   if [[ -e ${working_manifest_file} ]]; then
#     manifested_plugins=($(jq -r '.[] | .name + " " + .source' "${working_manifest_file}"))
#   else
#     local built_manifest_file="$(bin.build_manifest)"
#     manifested_plugins=($(jq -r '.[] | .name + " " + .source' "${built_manifest_file}"))
#   fi
#   local fixed_manifest_file="$(bin.fix_invalid_home_paths "${manifested_plugins[*]}")"
#   cp -f "${fixed_manifest_file}" "${working_manifest_file}"
#   fixed_manifest_file="$(bin.add_missing_plugins_to_manifest)"
#   cp -f "${fixed_manifest_file}" "${working_manifest_file}"
#   echo "${working_manifest_file}"
# }
# bin.download_plugins() {
#   local manifest_file="$1"
#   local tmp_plugins_dir="$2"
#   if [[ ! -d "${tmp_plugins_dir}" ]]; then
#     return 1
#   fi
#   local manifested_plugins=($(jq -r '.[] | .name + " " + .source' "${manifest_file}"))
#   local i=0
#   for manifested_plugin in ${manifested_plugins[@]}; do
#     if [[ $((i % 2)) -eq 1 ]]; then
#       local source="${manifested_plugin}"
#       local plugin_name="${manifested_plugins[$((i - 1))]}"
#       if [[ ! ${source} =~ ^http ]]; then
#         continue
#       fi
#       local plugins_config="${tmp_plugins_dir}/${plugin_name}/solos.json"
#       if [[ ! -f "${plugins_config}" ]]; then
#         echo "Plugin config not found: ${plugins_config}" >&2
#         return 1
#       fi
#       local plugin_source="$(jq -r '.source' "${plugins_config}")"
#       if [[ ${plugin_source} = "${source}" ]]; then
#         continue
#       fi
#       local plugin_path="${tmp_plugins_dir}/${plugin_name}"
#       rm -f "${plugin_path}/plugin"
#       curl -sSL "${source}" -o "${plugin_path}/plugin"
#     fi
#     i=$((i + 1))
#   done
# }
# bin.apply_manifest() {
#   local repaired_manifest="$(bin.repair_manifest)"
#   local tmp_plugins_dir="$(mktemp -d)"
#   cp -arf "${HOME}/.solos/plugins/"* "${tmp_plugins_dir}"
#   bin.download_plugins "${repaired_manifest}" "${tmp_plugins_dir}"
#   rm -rf "${HOME}/.solos/plugins"
#   cp -arf "${tmp_plugins_dir}" "${HOME}/.solos/plugins"
# }

plugin_name="farts"
plugin_url="https://farts.com/farts"
bashrc_plugins__manifest_file="${HOME}/.solos/plugins/manifest.json"
code_workspace_file="${HOME}/.solos/projects/saas/.vscode/saas.code-workspace"

arg_plugin_name="testing"
plugin_path="${HOME}/.solos/plugins/${arg_plugin_name}"

jq \
  --arg app_name "${arg_plugin_name}" \
  '.folders |= [{ "name": "plugin.'"${arg_plugin_name}"'", "uri": "'"${plugin_path}"'", "profile": "shell" }] + .' \
  "${code_workspace_file}" \
  >"${code_workspace_file}.tmp"

# jq ".folders += [{\"name\": \"plugin.${arg_plugin_name}\", \"uri\": \"${plugin_path}\", \"profile\": \"shell\"}]" "${code_workspace_file}" >"${code_workspace_file}.tmp"
mv "${code_workspace_file}.tmp" "${code_workspace_file}"
