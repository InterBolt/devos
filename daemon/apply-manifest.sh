#!/usr/bin/env bin__manifest_file

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/daemon/shared.sh" || exit 1

apply_manifest__manifest_file="${HOME}/.solos/plugins/solos.manifest.json"

apply_manifest.validate() {
  if [[ ! -f ${apply_manifest__manifest_file} ]]; then
    shared.log_error "Applying manifest - does not exist at ${apply_manifest__manifest_file}"
    return 1
  fi
  local manifest="$(cat ${apply_manifest__manifest_file})"
  if [[ ! $(jq '.' <<<"${manifest}") ]]; then
    shared.log_error "Applying manifest - not valid json at ${apply_manifest__manifest_file}"
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
    local plugin_config_path="${plugin_path}/solos.config.json"
    local plugin_source="${plugin_sources[${i}]}"
    if [[ ! -d ${plugin_path} ]]; then
      missing_plugins+=("${plugin_name}" "${plugin_source}")
      i=$((i + 1))
      continue
    fi
    if [[ ! -f ${plugin_executable_path} ]]; then
      shared.log_error "Applying manifest - plugin ${plugin_name} does not exist at: ${plugin_path}"
      return 1
    fi
    if [[ ! -f ${plugin_config_path} ]]; then
      shared.log_error "Applying manifest - plugin ${plugin_name} does not have a config file at: ${plugin_config_path}"
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
apply_manifest.init_config() {
  local source="${1}"
  local path="${2}"
  cat <<EOF >"${path}"
{
  "source": "${missing_plugin_source}"
  "config": {}
}
EOF
}
apply_manifest.download_sources() {
  local plugin_source="${1}"
  local output_path="${2}"
  if ! curl -o "${output_path}" "${plugin_source}"; then
    shared.log_error "Applying manifest - curl unable to download ${plugin_source}"
    return 1
  fi
  if ! chmod +x "${output_path}"; then
    shared.log_error "Applying manifest - unable to make ${output_path} executable"
    return 1
  fi
}
apply_manifest.commit_dirs() {
  local plugins_dir="${1}"
  local dirs=($(echo "${2}" | xargs))
  for dir in ${dirs[@]}; do
    local plugin_name="$(basename ${dir})"
    local plugin_path="${plugins_dir}/${plugin_name}"
    if [[ -d ${plugin_path} ]]; then
      shared.log_error "Applying manifest - plugin ${plugin_name} already exists at ${plugin_path}"
      return 1
    fi
    mv "${dir}" "${plugin_path}"
  done
}
apply_manifest.create_plugins() {
  local plugins_dir="${1}"
  local plugins_and_sources=($(echo "${2}" | xargs))
  local plugin_tmp_dirs=()
  local i=0
  for missing_plugin_name in ${plugins_and_sources[@]}; do
    if [[ $((i % 2)) -eq 0 ]]; then
      local tmp_dir="$(mktemp -d)"
      local missing_plugin_source="${plugins_and_sources[$((i + 1))]}"
      local tmp_config_path="${tmp_dir}/solos.config.json"
      local tmp_executable_path="${tmp_dir}/plugin"
      apply_manifest.init_config "${missing_plugin_source}" "${tmp_config_path}" || return 1
      apply_manifest.download_sources "${missing_plugin_source}" "${tmp_executable_path}" || return 1
      plugin_tmp_dirs+=("${tmp_dir}")
    fi
    i=$((i + 1))
  done
  apply_manifest.commit_dirs "${plugins_dir}" "${plugin_tmp_dirs[*]}" || return 1
}
apply_manifest.update_sources() {
  local plugins_dir="${1}"
  local plugins_and_sources=($(echo "${2}" | xargs))
  local plugin_tmp_dirs=()
  local i=0
  for changed_plugin_name in ${plugins_and_sources[@]}; do
    if [[ $((i % 2)) -eq 0 ]]; then
      local tmp_dir="$(mktemp -d)"
      local changed_plugin_source="${plugins_and_sources[$((i + 1))]}"
      local tmp_config_path="${tmp_dir}/solos.config.json"
      local current_config_path="${plugins_dir}/${changed_plugin_name}/solos.config.json"
      if [[ ! -d ${current_config_path} ]]; then
        apply_manifest.init_config "${changed_plugin_source}" "${tmp_config_path}"
      fi
      cp -f "${current_config_path}" "${tmp_config_path}"
      jq ".source = \"${changed_plugin_source}\"" "${tmp_config_path}" >"${tmp_config_path}.tmp"
      mv "${tmp_config_path}.tmp" "${tmp_config_path}"
      rm -f "${tmp_dir}/plugin"
      apply_manifest.download_sources "${changed_plugin_source}" "${tmp_dir}/plugin" || return 1
      plugin_tmp_dirs+=("${tmp_dir}")
    fi
  done
  apply_manifest.commit_dirs "${plugins_dir}" "${plugin_tmp_dirs[*]}" || return 1
}
apply_manifest.main() {
  local plugins_dir="${HOME}/.solos/plugins"

  # Validate to see if we need to fix.
  local return_file="$(mktemp)"
  apply_manifest.validate >"${return_file}" || return 1
  local returned="$(cat ${return_file})"
  local missing_plugins_and_sources=($(lib.line_to_args "${returned}" 0))
  local changed_plugins_and_sources=($(lib.line_to_args "${returned}" 1))
  local tmp_plugins_dir="$(mktemp -d)/plugins"
  if ! cp -rfa "${plugins_dir}/" "${tmp_plugins_dir}/"; then
    shared.log_error "Applying manifest - unable to copy ${plugins_dir} to ${tmp_plugins_dir}"
    return 1
  fi

  # Do the fixing.
  apply_manifest.create_plugins "${tmp_plugins_dir}" "${missing_plugins_and_sources[*]}" || return 1
  apply_manifest.update_sources "${tmp_plugins_dir}" "${changed_plugins_and_sources[*]}" || return 1

  # Validate again to see if we fixed it.
  local return_file="$(mktemp)"
  apply_manifest.validate >"${return_file}" || return 1
  local returned="$(cat ${return_file})"
  local missing_plugins_and_sources=($(lib.line_to_args "${returned}" 0))
  local changed_plugins_and_sources=($(lib.line_to_args "${returned}" 1))
  if [[ ${#missing_plugins_and_sources[@]} -gt 0 ]]; then
    shared.log_error "Applying manifest - missing plugins: ${missing_plugins_and_sources[*]}"
    return 1
  fi
  if [[ ${#changed_plugins_and_sources[@]} -gt 0 ]]; then
    shared.log_error "Applying manifest - changed plugins: ${changed_plugins_and_sources[*]}"
    return 1
  fi

  # Move the new plugins into place.
  rm -rf "${plugins_dir}"
  mkdir -p "${plugins_dir}"
  cp -rfa "${tmp_plugins_dir}/" "${plugins_dir}/"
}
