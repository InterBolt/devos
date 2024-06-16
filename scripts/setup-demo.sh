#!/bin/bash

main() {
  local solos_dir="${HOME}/.solos"
  local plugins_dir="${solos_dir}/plugins"
  local manifest_file="${plugins_dir}/demo.manifest.json"
  local mock_plugin_downloads_path="mock/remote-plugin-downloads"
  local mock_remote_plugin_downloads_dir="${solos_dir}/src/${mock_plugin_downloads_path}"
  local local_plugins=(
    "alpha"
    "bravo"
    "charlie"
  )
  local remote_plugins=(
    $(find \
      "${mock_remote_plugin_downloads_dir}" \
      -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
  )
  echo "[]" >"${manifest_file}"
  for local_plugin in "${local_plugins[@]}"; do
    mkdir -p "${plugins_dir}/${local_plugin}"
  done
  for plugin in "${remote_plugins[@]}"; do
    local remote_url="https://raw.githubusercontent.com/InterBolt/solos/main/${mock_plugin_downloads_path}/${plugin}.sh"
    jq ". += [{\"name\":\"${plugin}\", \"source\":\"${remote_url}\"}]" \
      "${manifest_file}" >"${manifest_file}.tmp"
    mv "${manifest_file}.tmp" "${manifest_file}"
  done
  echo "Manifest file created at ${manifest_file}"
}

main
