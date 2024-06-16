#!/bin/bash

main() {
  local solos_dir="${HOME}/.solos"
  local plugins_dir="${solos_dir}/plugins"
  if [[ -d "${plugins_dir}" ]]; then
    rm -rf "${plugins_dir}"
    mkdir -p "${plugins_dir}"
  fi
  local manifest_file="${plugins_dir}/solos.manifest.json"
  local mock_plugin_downloads_path="mock/remote-plugin-downloads"
  local mock_remote_plugin_downloads_dir="${solos_dir}/src/${mock_plugin_downloads_path}"
  local precheck_script="${solos_dir}/src/plugins/precheck/plugin"
  local local_plugins=(
    "alpha"
    "bravo"
    "charlie"
  )
  local remote_plugins=(
    $(find \
      "${mock_remote_plugin_downloads_dir}" \
      -mindepth 1 -maxdepth 1 -type f -exec basename {} \;)
  )
  echo "[]" >"${manifest_file}"
  for local_plugin in "${local_plugins[@]}"; do
    mkdir -p "${plugins_dir}/${local_plugin}"
    cp "${precheck_script}" "${plugins_dir}/${local_plugin}/plugin"
  done
  for plugin_file in "${remote_plugins[@]}"; do
    local plugin_name="${plugin_file%.sh}"
    local remote_url="https://raw.githubusercontent.com/InterBolt/solos/main/${mock_plugin_downloads_path}/${plugin_name}.sh"
    jq ". += [{\"name\":\"${plugin_name}\", \"source\":\"${remote_url}\"}]" \
      "${manifest_file}" >"${manifest_file}.tmp"
    mv "${manifest_file}.tmp" "${manifest_file}"
  done
  echo "${manifest_file}"
}

main
