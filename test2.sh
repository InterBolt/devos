#!/bin/bash

lib.line_to_args() {
  local lines="${1}"
  local index="${2}"
  if [[ ${index} -eq 0 ]]; then
    echo "${lines}" | head -n 1 | xargs
  else
    echo "${lines}" | head -n "$((index + 1))" | tail -n 1 | xargs
  fi
}

# We're hacking on an idea around managing SolOS plugins via a manifest file.
# The manifest file is a json file that contains an array of objects: { name: string, source: string }
# The name is somewhat arbitrary but should be unique in the $HOME/.solos/plugins/ directory.
# Local plugins are possible but they are not specified or managed by the manifest file. While we should ensure
# that local plugin names do not overlap with those defined in the manifest, that's the extent of the manifest.json
# awareness of local plugins.

# Notes:
# manifest.json lives at $HOME/.solos/plugins/manifest.json
# plugins live at $HOME/.solos/plugins/<plugin_name>/

# Rather than add "repairing" and such functionality, start with a simple flow:
# 1. Validate manifest.json and if it's not valid return a non-zero exit code.
#    We operate on the assumption that this might realistically never happen since we'll have a cli tool that we build later to interact with the manifest.json file.
# 2. Validate that all plugins in the manifest.json file exist on the filesystem. If a plugin's name is "foo" then there should be a directory at $HOME/.solos/plugins/foo/
# 3. If any existing local plugins overlap with one of the names, return a non-zero exit code.

bin__manifest_file="${HOME}/.solos/plugins/manifest.json"

bin.validate_manifest() {
  if [[ ! -f ${bin__manifest_file} ]]; then
    echo "Manifest file does not exist at ${bin__manifest_file}" >&2
    return 1
  fi
  local manifest="$(cat ${bin__manifest_file})"
  if [[ ! $(jq '.' <<<"${manifest}") ]]; then
    echo "Manifest file is not valid json" >&2
    return 1
  fi
  local missing_plugins=()
  local changed_plugins=()
  local plugin_names=($(jq -r '.[].name' <<<"${manifest}"))
  local plugin_sources=($(jq -r '.[].source' <<<"${manifest}"))
  local i=0
  for plugin_name in ${plugin_names[@]}; do
    local plugin_path="${HOME}/.solos/plugins/${plugin_name}"
    local plugin_executable_path="${plugin_path}/plugin"
    local plugin_config_path="${plugin_path}/config.json"
    local plugin_source="${plugin_sources[${i}]}"
    if [[ ! -d ${plugin_path} ]]; then
      missing_plugins+=("${plugin_name}" "${plugin_source}")
      i=$((i + 1))
      continue
    fi
    if [[ ! -f ${plugin_executable_path} ]]; then
      echo "Invalid manifest - plugin ${plugin_name} does not exist at: ${plugin_path}" >&2
      return 1
    fi
    if [[ ! -f ${plugin_config_path} ]]; then
      echo "Invalid manifest - plugin ${plugin_name} does not have a config file at: ${plugin_config_path}" >&2
      return 1
    fi
    local plugin_config_source="$(jq -r '.source' ${plugin_config_path})"
    if [[ ${plugin_config_source} != "${plugin_source}" ]]; then
      changed_plugins+=("${plugin_name}" "${plugin_source}")
    fi
    i=$((i + 1))
  done
  echo "${missing_plugins[*]}"
  echo "${changed_plugins[*]}"
}
bin.setup_config() {
  local source="${1}"
  local path="${2}"
  cat <<EOF >"${path}"
{
  "source": "${missing_plugin_source}"
  "config": {}
}
EOF
}
bin.download_plugin() {
  local plugin_source="${1}"
  local output_path="${2}"
  if ! curl -o "${output_path}" "${plugin_source}"; then
    echo "Install failed - curl unable to download ${plugin_source}" >&2
    return 1
  fi
  if ! chmod +x "${output_path}"; then
    echo "Install failed - unable to make ${output_path} executable" >&2
    return 1
  fi
}
bin.commit_plugin_dirs() {
  local plugins_dir="${1}"
  local dirs=($(echo "${2}" | xargs))
  for dir in ${dirs[@]}; do
    local plugin_name="$(basename ${dir})"
    local plugin_path="${plugins_dir}/${plugin_name}"
    if [[ -d ${plugin_path} ]]; then
      echo "Install failed - plugin ${plugin_name} already exists at ${plugin_path}" >&2
      return 1
    fi
    mv "${dir}" "${plugin_path}"
  done
}
bin.add_plugins() {
  local plugins_dir="${1}"
  local plugins_and_sources=($(echo "${2}" | xargs))
  local plugin_tmp_dirs=()
  local i=0
  for missing_plugin_name in ${plugins_and_sources[@]}; do
    if [[ $((i % 2)) -eq 0 ]]; then
      local tmp_dir="$(mktemp -d)"
      local missing_plugin_source="${plugins_and_sources[$((i + 1))]}"
      local tmp_config_path="${tmp_dir}/config.json"
      local tmp_executable_path="${tmp_dir}/plugin"
      bin.setup_config "${missing_plugin_source}" "${tmp_config_path}" || return 1
      bin.download_plugin "${missing_plugin_source}" "${tmp_executable_path}" || return 1
      plugin_tmp_dirs+=("${tmp_dir}")
    fi
    i=$((i + 1))
  done
  bin.commit_plugin_dirs "${plugins_dir}" "${plugin_tmp_dirs[*]}" || return 1
}
bin.update_plugins() {
  local plugins_dir="${1}"
  local plugins_and_sources=($(echo "${2}" | xargs))
  local plugin_tmp_dirs=()
  local i=0
  for changed_plugin_name in ${plugins_and_sources[@]}; do
    if [[ $((i % 2)) -eq 0 ]]; then
      local tmp_dir="$(mktemp -d)"
      local changed_plugin_source="${plugins_and_sources[$((i + 1))]}"
      local tmp_config_path="${tmp_dir}/config.json"
      local current_config_path="${plugins_dir}/${changed_plugin_name}/config.json"
      if [[ ! -d ${current_config_path} ]]; then
        bin.setup_config "${changed_plugin_source}" "${tmp_config_path}"
      fi
      cp -f "${current_config_path}" "${tmp_config_path}"
      rm -f "${tmp_dir}/plugin"
      bin.download_plugin "${changed_plugin_source}" "${tmp_dir}/plugin" || return 1
    fi
  done
  bin.commit_plugin_dirs "${plugins_dir}" "${plugin_tmp_dirs[*]}" || return 1
}
bin.commit_all() {
  local next_dir="${1}"
  rm -rf "${HOME}/.solos/plugins" || return 1
  mv "${next_dir}" "${HOME}/.solos/plugins" || return 1
}
bin.apply_manifest() {
  local tmp_backup="$(mktemp -d)"
  local tmp_file="$(mktemp)"
  local plugins_dir="${HOME}/.solos/plugins"
  bin.validate_manifest >"${tmp_file}" || return 1
  local tmp_dir="$(mktemp -d)"
  local tmp_plugins_dir="${tmp_dir}/plugins"
  if ! cp -rfa "${plugins_dir}" "${tmp_plugins_dir}"; then
    echo "Install failed - unable to copy ${plugins_dir} to ${tmp_plugins_dir}" >&2
    return 1
  fi
  local validated="$(cat ${tmp_file})"
  local missing_plugins_and_sources=($(lib.line_to_args "${validated}" 0))
  local changed_plugins_and_sources=($(lib.line_to_args "${validated}" 1))
  bin.add_plugins "${tmp_plugins_dir}" "${missing_plugins_and_sources[*]}" || return 1
  bin.update_plugins "${tmp_plugins_dir}" "${changed_plugins_and_sources[*]}" || return 1
  cp -rfa "${plugins_dir}/" "${tmp_backup}/"
  rm -rf "${plugins_dir}"
  mkdir -p "${plugins_dir}"
  cp -rfa "${tmp_plugins_dir}/" "${plugins_dir}/"
}

main
