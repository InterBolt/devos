#!/usr/bin/env bash

. "${HOME}/.solos/repo/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/repo/src/shared/log.sh" || exit 1

daemon__pid=$$
daemon__remaining_retries=5
daemon__solos_dir="${HOME}/.solos"
daemon__daemon_data_dir="${daemon__solos_dir}/data/daemon"
daemon__user_plugins_dir="${daemon__solos_dir}/plugins"
daemon__manifest_file="${daemon__user_plugins_dir}/solos.manifest.json"
daemon__solos_plugins_dir="${daemon__solos_dir}/repo/src/daemon/plugins"
daemon__panics_dir="${daemon__solos_dir}/data/panics"
daemon__precheck_plugin_path="${daemon__solos_plugins_dir}/precheck"
daemon__users_home_dir="$(lib.home_dir_path)"
daemon__pid_file="${daemon__daemon_data_dir}/pid"
daemon__status_file="${daemon__daemon_data_dir}/status"
daemon__request_file="${daemon__daemon_data_dir}/request"
daemon__log_file="${daemon__daemon_data_dir}/master.log"
daemon__prev_pid="$(cat "${daemon__pid_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon__precheck_plugin_names=("precheck")
daemon__checked_out_project="$(lib.checked_out_project)"
daemon__checked_project_path="/root/.solos/projects/${daemon__checked_out_project}"
daemon__tmp_data_dir="${daemon__daemon_data_dir}/tmp"
daemon__blacklisted_exts=(
  "pem"
  "key"
  "cer"
  "crt"
  "der"
  "pfx"
  "p12"
  "p7b"
  "p7c"
  "p7a"
  "p8"
  "spc"
  "rsa"
  "jwk"
  "pri"
  "bin"
  "asc"
  "gpg"
  "pgp"
  "kdb"
  "kdbx"
  "ovpn"
  "enc"
  "jks"
  "keystore"
  "ssh"
  "ppk"
  "xml"
  "bak"
  "zip"
  "tar"
  "gz"
  "tgz"
  "rar"
  "java"
  "rtf"
  "xlsx"
  "pptx"
)

mkdir -p "${daemon__daemon_data_dir}"
log.use "${daemon__log_file}"

declare -A statuses=(
  ["UP"]="The daemon is running."
  ["RECOVERING"]="The daemon is recovering from a nonfatal error."
  ["RUN_FAILED"]="The daemon plugin lifecycle failed in an unrecoverable way and stopped running to limit damage."
  ["START_FAILED"]="The daemon failed to start up."
  ["KILLED"]="The user killed the daemon process."
)
daemon.get_host_path() {
  local path="${1}"
  echo "${path/\/root\//${daemon__users_home_dir}\/}"
}
daemon.log_info() {
  local message="(DAEMON) ${1} pid=\"${daemon__pid}\""
  shift
  log.info "${message}" "$@"
}
daemon.log_error() {
  local message="(DAEMON) ${1} pid=\"${daemon__pid}\""
  shift
  log.error "${message}" "$@"
}
daemon.log_warn() {
  local message="(DAEMON) ${1} pid=\"${daemon__pid}\""
  shift
  log.warn "${message}" "$@"
}
daemon.get_solos_plugin_names() {
  local solos_plugin_names=()
  local plugins_dirbasename="$(basename "${daemon__solos_plugins_dir}")"
  for solos_plugin_path in "${daemon__solos_plugins_dir}"/*; do
    if [[ ${solos_plugin_path} = "${plugins_dirbasename}" ]]; then
      continue
    fi
    if [[ -d ${solos_plugin_path} ]]; then
      solos_plugin_names+=("solos-$(basename "${solos_plugin_path}")")
    fi
  done
  echo "${solos_plugin_names[@]}" | xargs
}
daemon.get_user_plugin_names() {
  local user_plugin_names=()
  local plugins_dirbasename="$(basename "${daemon__user_plugins_dir}")"
  for user_plugin_path in "${daemon__user_plugins_dir}"/*; do
    if [[ ${user_plugin_path} = "${plugins_dirbasename}" ]]; then
      continue
    fi
    if [[ -d ${user_plugin_path} ]]; then
      user_plugin_names+=("user-$(basename "${user_plugin_path}")")
    fi
  done
  echo "${user_plugin_names[@]}" | xargs
}
daemon.plugin_paths_to_names() {
  local plugins=($(echo "${1}" | xargs))
  local plugin_names=()
  for plugin in "${plugins[@]}"; do
    if [[ ${plugin} = "${daemon__precheck_plugin_path}" ]]; then
      plugin_names+=("${daemon__precheck_plugin_names[@]}")
    elif [[ ${plugin} =~ ^"${daemon__user_plugins_dir}" ]]; then
      plugin_names+=("user-$(basename "${plugin}")")
    else
      plugin_names+=("solos-$(basename "${plugin}")")
    fi
  done
  echo "${plugin_names[*]}" | xargs
}
daemon.plugin_names_to_paths() {
  local plugin_names=($(echo "${1}" | xargs))
  local plugins=()
  for plugin_name in "${plugin_names[@]}"; do
    if [[ ${plugin_name} = "precheck" ]]; then
      plugins+=("${daemon__precheck_plugin_path}")
    elif [[ ${plugin_name} =~ ^solos- ]]; then
      plugin_name="${plugin_name#solos-}"
      plugins+=("${daemon__solos_plugins_dir}/${plugin_name}")
    elif [[ ${plugin_name} =~ ^user- ]]; then
      plugin_name="${plugin_name#user-}"
      plugins+=("${daemon__user_plugins_dir}/${plugin_name}")
    fi
  done
  echo "${plugins[*]}" | xargs
}
daemon.status() {
  local status="$1"
  if [[ -z ${statuses[${status}]} ]]; then
    daemon.log_error "Tried to update to an invalid status: \"${status}\""
    exit 1
  fi
  echo "${status}" >"${daemon__status_file}"
  daemon.log_info "Update status to: \"${status}\" - \"${statuses[${status}]}\""
}

trap 'rm -rf "'"${daemon__tmp_data_dir}"'"' EXIT

daemon.project_found() {
  if [[ -z ${daemon__checked_out_project} ]]; then
    daemon.log_error "No project is checked out."
    return 1
  fi
  if [[ ! -d ${daemon__checked_project_path} ]]; then
    daemon.log_error "\"${daemon__checked_project_path}\" does not exist."
    return 1
  fi
}
daemon.create_scrub_copy() {
  local cp_tmp_dir="$(mktemp -d)"
  local tmp_dir="${daemon__tmp_data_dir}"
  if ! rm -rf "${tmp_dir}"; then
    daemon.log_error "failed to remove the existing temporary directory."
    return 1
  fi
  daemon.log_info "Cleared the previous temporary directory: \"${tmp_dir}\""
  mkdir -p "${tmp_dir}"
  if [[ -z ${tmp_dir} ]]; then
    daemon.log_error "failed to create a temporary directory for the safe copy."
    return 1
  fi
  if ! mkdir -p "${cp_tmp_dir}/projects/${daemon__checked_out_project}"; then
    daemon.log_error "failed to create the projects directory in the temporary directory."
    return 1
  fi
  daemon.log_info "Created temporary directory: \"${cp_tmp_dir}\""
  if ! cp -rfa "${daemon__checked_project_path}/." "${cp_tmp_dir}/projects/${daemon__checked_out_project}"; then
    daemon.log_error "failed to copy the project directory: \"${daemon__checked_project_path}\" to: \"${tmp_dir}/projects/${daemon__checked_out_project}\""
    return 1
  fi
  local root_paths=($(find /root/.solos -maxdepth 1 | xargs))
  for root_path in "${root_paths[@]}"; do
    local base="$(basename "${root_path}")"
    if [[ ${base} = "projects" ]]; then
      continue
    fi
    if [[ ${base} = ".solos" ]]; then
      continue
    fi
    if ! mkdir -p "${cp_tmp_dir}/${base}"; then
      daemon.log_error "failed to create the directory: \"${cp_tmp_dir}/${base}\""
      return 1
    fi
    if [[ -d ${root_path} ]]; then
      if ! cp -r "${root_path}/." "${cp_tmp_dir}/${base}"; then
        daemon.log_error "failed to copy: \"${root_path}\" to: \"${cp_tmp_dir}/${base}\""
        return 1
      fi
    else
      if ! cp "${root_path}" "${cp_tmp_dir}/${base}"; then
        daemon.log_error "failed to copy: \"${root_path}\" to: \"${cp_tmp_dir}/${base}\""
        return 1
      fi
    fi
  done
  local random_dirname="$(date +%s | sha256sum | base64 | head -c 32)"
  mv "${cp_tmp_dir}" "${tmp_dir}/${random_dirname}"
  echo "${tmp_dir}/${random_dirname}"
}
daemon.scrub_ssh() {
  local tmp_dir="${1}"
  local ssh_dirpaths=($(find "${tmp_dir}" -type d -name ".ssh" -o -name "ssh" | xargs))
  for ssh_dirpath in "${ssh_dirpaths[@]}"; do
    if ! rm -rf "${ssh_dirpath}"; then
      daemon.log_error "failed to remove the SSH directory: \"${ssh_dirpath}\" from the temporary directory."
      return 1
    fi
    daemon.log_info "Deleted \"${ssh_dirpath}\""
  done
}
daemon.scub_blacklisted_files() {
  local tmp_dir="${1}"
  local find_args=()
  for suspect_extension in "${daemon__blacklisted_exts[@]}"; do
    if [[ ${#find_args[@]} -eq 0 ]]; then
      find_args+=("-name" "*.${suspect_extension}")
      continue
    fi
    find_args+=("-o" "-name" "*.${suspect_extension}")
  done
  local secret_filepaths=($(find "${tmp_dir}" -type f "${find_args[@]}" | xargs))
  for secret_filepath in "${secret_filepaths[@]}"; do
    if ! rm -f "${secret_filepath}"; then
      daemon.log_error "failed to remove the suspect secret file: \"${secret_filepath}\" from the temporary directory."
      return 1
    fi
    daemon.log_info "Deleted \"${secret_filepath}\""
  done
}
daemon.scrub_gitignored() {
  local tmp_dir="${1}"
  local git_dirs=($(find "${tmp_dir}" -type d -name ".git" | xargs))
  for git_dir in "${git_dirs[@]}"; do
    local git_project_path="$(dirname "${git_dir}")"
    local gitignore_path="${git_project_path}/.gitignore"
    if [[ ! -f "${gitignore_path}" ]]; then
      daemon.log_warn "No .gitignore file found in git repo: \"${git_project_path}\""
      continue
    fi
    local gitignored_paths_to_delete=($(git -C "${git_project_path}" status -s --ignored | grep "^\!\!" | cut -d' ' -f2 | xargs))
    for gitignored_path_to_delete in "${gitignored_paths_to_delete[@]}"; do
      gitignored_path_to_delete="${git_project_path}/${gitignored_path_to_delete}"
      if ! rm -rf "${gitignored_path_to_delete}"; then
        daemon.log_error "\"${gitignored_path_to_delete}\" from the temporary directory."
        return 1
      fi
      daemon.log_info "Deleted \"${gitignored_path_to_delete}\""
    done
  done
}
daemon.scrub_secrets() {
  local tmp_dir="${1}"
  local secrets=()
  # Extract global secrets.
  local global_secret_filepaths=($(find "${tmp_dir}"/secrets -maxdepth 1 | xargs))
  local i=0
  for global_secret_filepath in "${global_secret_filepaths[@]}"; do
    if [[ -d ${global_secret_filepath} ]]; then
      continue
    fi
    secrets+=("$(cat "${global_secret_filepath}" 2>/dev/null || echo "" | head -n 1)")
    i=$((i + 1))
  done
  daemon.log_info "Found extracted ${i} secrets in global secret dir: ${tmp_dir}/secrets"
  # Extract project secrets.
  local project_paths=($(find "${tmp_dir}"/projects -maxdepth 1 | xargs))
  for project_path in "${project_paths[@]}"; do
    local project_secrets_path="${project_path}/secrets"
    if [[ ! -d ${project_secrets_path} ]]; then
      continue
    fi
    local project_secret_filepaths=($(find "${project_secrets_path}" -maxdepth 1 | xargs))
    local i=0
    for project_secret_filepath in "${project_secret_filepaths[@]}"; do
      if [[ -d ${project_secret_filepath} ]]; then
        continue
      fi
      secrets+=("$(cat "${project_secret_filepath}" 2>/dev/null || echo "" | head -n 1)")
      i=$((i + 1))
    done
    daemon.log_info "Found extracted ${i} secrets in project secret dir: ${project_secrets_path}"
  done
  # Extract .env secrets.
  local env_filepaths=($(find "${tmp_dir}" -type f -name ".env"* -o -name ".env" | xargs))
  for env_filepath in "${env_filepaths[@]}"; do
    local env_secrets=($(cat "${env_filepath}" | grep -v '^#' | grep -v '^$' | sed 's/^[^=]*=//g' | sed 's/"//g' | sed "s/'//g" | xargs))
    local i=0
    for env_secret in "${env_secrets[@]}"; do
      secrets+=("${env_secret}")
      i=$((i + 1))
    done
    daemon.log_info "Found extracted ${i} secrets from file: ${env_filepath}"
  done
  # Remove duplicates.
  secrets=($(printf "%s\n" "${secrets[@]}" | sort -u))
  # Scrub.
  for secret in "${secrets[@]}"; do
    input_files=$(grep -rl "${secret}" "${tmp_dir}")
    if [[ -z ${input_files} ]]; then
      continue
    fi
    while IFS= read -r input_file; do
      if ! sed -E -i "s@${secret}@[REDACTED]@g" "${input_file}"; then
        daemon.log_error "\"${secret}\" from ${input_file}."
        return 1
      fi
    done <<<"${input_files}"
    daemon.log_info "Scrubbed secret: \"${secret}\""
  done
}
daemon.scrub() {
  if ! daemon.project_found; then
    return 1
  fi
  local tmp_dir="$(daemon.create_scrub_copy)"
  if [[ ! -d ${tmp_dir} ]]; then
    return 1
  fi
  daemon.log_info "Copied solos to: ${tmp_dir}"
  if ! daemon.scrub_gitignored "${tmp_dir}"; then
    return 1
  fi
  daemon.log_info "Removed gitignored paths from: ${tmp_dir}"
  if ! daemon.scrub_ssh "${tmp_dir}"; then
    return 1
  fi
  daemon.log_info "Removed SSH directories from: ${tmp_dir}"
  if ! daemon.scub_blacklisted_files "${tmp_dir}"; then
    return 1
  fi
  daemon.log_info "Deleted potentially sensitive files based on an extension blacklist."
  if ! daemon.scrub_secrets "${tmp_dir}"; then
    return 1
  fi
  daemon.log_info "Scrubbed known secrets."
  echo "${tmp_dir}"
}
daemon.extract_request() {
  local request_file="${1}"
  if [[ -f ${request_file} ]]; then
    local contents="$(cat "${request_file}" 2>/dev/null || echo "" | head -n 1 | xargs)"
    rm -f "${request_file}"
    local requested_pid="$(echo "${contents}" | cut -d' ' -f1)"
    local requested_action="$(echo "${contents}" | cut -d' ' -f2)"
    if [[ ${requested_pid} -eq ${daemon__pid} ]]; then
      echo "${requested_action}"
      return 0
    fi
    if [[ -n ${requested_pid} ]]; then
      daemon.log_error "Unexpected - the requested pid in the daemon's request file: ${request_file} is not the current daemon pid: ${daemon__pid}."
      exit 1
    fi
  else
    return 1
  fi
}
daemon.execute_request() {
  local request="${1}"
  case "${request}" in
  "KILL")
    daemon.log_info "Requested KILL was detected. Killing the daemon process."
    daemon.status "KILLED"
    exit 0
    ;;
  *)
    daemon.log_error "Unexpected - unknown user request ${request}"
    exit 1
    ;;
  esac
}
daemon.handle_requests() {
  local request="$(daemon.extract_request "${daemon__request_file}")"
  if [[ -n ${request} ]]; then
    daemon.log_info "Request  ${request} was dispatched to the daemon."
    daemon.execute_request "${request}"
  else
    daemon.log_info "Request found none. Will continue to run the daemon."
  fi
}
daemon.apply_config_updates() {
  local merged_configure_dir="${1}"
  local solos_plugin_names=($(daemon.get_solos_plugin_names))
  local user_plugin_names=($(daemon.get_user_plugin_names))
  local plugin_names=($(echo "${daemon__precheck_plugin_names[*]} ${solos_plugin_names[*]} ${user_plugin_names[*]}" | xargs))
  local plugin_paths=($(daemon.plugin_names_to_paths "${plugin_names[*]}" | xargs))
  local i=0
  for plugin_path in "${plugin_paths[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    local config_path="${plugin_path}/solos.config.json"
    local updated_config_path="${merged_configure_dir}/${plugin_name}.json"
    if [[ -f ${updated_config_path} ]]; then
      rm -f "${config_path}"
      cp "${updated_config_path}" "${config_path}"
      daemon.log_info "Updated the config at ${config_path}."
    fi
    i=$((i + 1))
  done
}
daemon.stash_plugin_logs() {
  local phase="${1}"
  local log_file="${2}"
  local aggregated_stdout_file="${3}"
  local aggregated_stderr_file="${4}"
  echo "[${phase} phase:stdout]" >>"${log_file}"
  while IFS= read -r line; do
    echo "${line}" >>"${log_file}"
    daemon.log_info "${line}"
  done <"${aggregated_stdout_file}"
  echo "[${phase} phase:stderr]" >>"${log_file}"
  while IFS= read -r line; do
    echo "${line}" >>"${log_file}"
    daemon.log_error "${line}"
  done <"${aggregated_stderr_file}"
}
daemon.validate_manifest() {
  local plugins_dir="${1}"
  local manifest_file="${plugins_dir}/solos.manifest.json"
  if [[ ! -f ${manifest_file} ]]; then
    daemon.log_error "Does not exist at ${manifest_file}"
    return 1
  fi
  local manifest="$(cat ${manifest_file})"
  if [[ ! $(jq '.' <<<"${manifest}") ]]; then
    daemon.log_error "Not valid json at ${manifest_file}"
    return 1
  fi
  local missing_plugins=()
  local changed_plugins=()
  local plugin_names=($(jq -r '.[].name' <<<"${manifest}" | xargs))
  local plugin_sources=($(jq -r '.[].source' <<<"${manifest}" | xargs))
  local i=0
  for plugin_name in "${plugin_names[@]}"; do
    local plugin_path="${plugins_dir}/${plugin_name}"
    local plugin_executable_path="${plugin_path}/plugin"
    local plugin_config_path="${plugin_path}/solos.config.json"
    local plugin_source="${plugin_sources[${i}]}"
    if [[ ! -d ${plugin_path} ]]; then
      missing_plugins+=("${plugin_name}" "${plugin_source}")
      i=$((i + 1))
      continue
    fi
    if [[ ! -f ${plugin_executable_path} ]]; then
      daemon.log_warn "No executable at ${plugin_executable_path}. Will treat like a missing plugin."
      missing_plugins+=("${plugin_name}" "${plugin_source}")
      i=$((i + 1))
      continue
    fi
    local plugin_config_source="$(jq -r '.source' ${plugin_config_path})"
    if [[ ${plugin_config_source} != "${plugin_source}" ]]; then
      daemon.log_info "Plugin ${plugin_name} is CHANGING"
      changed_plugins+=("${plugin_name}" "${plugin_source}")
    fi
    i=$((i + 1))
  done
  echo "${missing_plugins[*]}" | xargs
  echo "${changed_plugins[*]}" | xargs
}
daemon.create_empty_plugin_config() {
  local source="${1}"
  local path="${2}"
  cat <<EOF >"${path}"
{
  "source": "${source}",
  "config": {}
}
EOF
}
daemon.curl_plugin() {
  local plugin_source="${1}"
  local output_path="${2}"
  if ! curl -s -o "${output_path}" "${plugin_source}"; then
    daemon.log_error "Curl unable to download ${plugin_source}"
    return 1
  fi
  daemon.log_info "Downloaded ${plugin_source} to ${output_path}"
  if ! chmod +x "${output_path}"; then
    daemon.log_error "Unable to make ${output_path} executable"
    return 1
  fi
  daemon.log_info "Made ${output_path} executable"
}
daemon.move_plugins() {
  local plugins_dir="${1}"
  local dirs=($(echo "${2}" | xargs))
  local plugin_names=($(echo "${3}" | xargs))
  local i=0
  for dir in "${dirs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    local plugin_path="${plugins_dir}/${plugin_name}"
    plugin_paths+=("${plugin_path}")
    if [[ -d ${plugin_path} ]]; then
      daemon.log_warn "Plugin ${plugin_name} already exists at ${plugin_path}. Skipping."
      i=$((i + 1))
      continue
    fi
    if ! mv "${dir}" "${plugin_path}"; then
      daemon.log_error "Unable to move ${dir} to ${plugin_path}"
      return 1
    fi
    i=$((i + 1))
  done
}
daemon.add_plugins() {
  local plugins_dir="${1}"
  local plugins_and_sources=($(echo "${2}" | xargs))
  local plugin_tmp_dirs=()
  local plugin_names=()
  local i=0
  for missing_plugin_name in "${plugins_and_sources[@]}"; do
    if [[ $((i % 2)) -eq 0 ]]; then
      local tmp_dir="$(mktemp -d)"
      local missing_plugin_source="${plugins_and_sources[$((i + 1))]}"
      local tmp_config_path="${tmp_dir}/solos.config.json"
      local tmp_executable_path="${tmp_dir}/plugin"
      daemon.create_empty_plugin_config "${missing_plugin_source}" "${tmp_config_path}" || return 1
      daemon.curl_plugin "${missing_plugin_source}" "${tmp_executable_path}" || return 1
      plugin_tmp_dirs+=("${tmp_dir}")
      plugin_names+=("${missing_plugin_name}")
    fi
    i=$((i + 1))
  done
  daemon.move_plugins "${plugins_dir}" "${plugin_tmp_dirs[*]}" "${plugin_names[*]}" || return 1
}
daemon.sync_manifest_sources() {
  local plugins_dir="${1}"
  local plugins_and_sources=($(echo "${2}" | xargs))
  local plugin_tmp_dirs=()
  local plugin_names=()
  local i=0
  for changed_plugin_name in "${plugins_and_sources[@]}"; do
    if [[ $((i % 2)) -eq 0 ]]; then
      local tmp_dir="$(mktemp -d)"
      local changed_plugin_source="${plugins_and_sources[$((i + 1))]}"
      local tmp_config_path="${tmp_dir}/solos.config.json"
      local current_config_path="${plugins_dir}/${changed_plugin_name}/solos.config.json"
      if [[ ! -d ${current_config_path} ]]; then
        daemon.create_empty_plugin_config "${changed_plugin_source}" "${tmp_config_path}"
      fi
      cp -f "${current_config_path}" "${tmp_config_path}"
      jq ".source = \"${changed_plugin_source}\"" "${tmp_config_path}" >"${tmp_config_path}.tmp"
      mv "${tmp_config_path}.tmp" "${tmp_config_path}"
      rm -f "${tmp_dir}/plugin"
      daemon.curl_plugin "${changed_plugin_source}" "${tmp_dir}/plugin" || return 1
      plugin_tmp_dirs+=("${tmp_dir}")
      plugin_names+=("${changed_plugin_name}")
    fi
  done
  daemon.move_plugins "${plugins_dir}" "${plugin_tmp_dirs[*]}" "${plugin_names[*]}" || return 1
}
daemon.update_plugins() {
  local plugins_dir="${HOME}/.solos/plugins"
  local return_file="$(mktemp)"
  daemon.validate_manifest "${plugins_dir}" >"${return_file}" || return 1
  local returned="$(cat ${return_file})"
  local missing_plugins_and_sources=($(lib.line_to_args "${returned}" "0"))
  local changed_plugins_and_sources=($(lib.line_to_args "${returned}" "1"))
  local tmp_plugins_dir="$(mktemp -d)"
  if ! cp -rfa "${plugins_dir}"/. "${tmp_plugins_dir}"/; then
    daemon.log_error "Unable to copy ${plugins_dir} to ${tmp_plugins_dir}"
    return 1
  fi
  local missing_count="${#missing_plugins_and_sources[@]}"
  missing_count=$((missing_count / 2))
  local change_count="${#changed_plugins_and_sources[@]}"
  change_count=$((change_count / 2))
  daemon.log_info "Found ${missing_count} missing plugins"
  daemon.log_info "Found ${change_count} changed plugins"
  daemon.add_plugins "${tmp_plugins_dir}" "${missing_plugins_and_sources[*]}" || return 1
  daemon.sync_manifest_sources "${tmp_plugins_dir}" "${changed_plugins_and_sources[*]}" || return 1
  return_file="$(mktemp)"
  daemon.validate_manifest "${tmp_plugins_dir}" >"${return_file}" || return 1
  returned="$(cat ${return_file})"
  local remaining_missing_plugins_and_sources=($(lib.line_to_args "${returned}" "0"))
  local remaining_changed_plugins_and_sources=($(lib.line_to_args "${returned}" "1"))
  if [[ ${#remaining_missing_plugins_and_sources[@]} -gt 0 ]]; then
    daemon.log_error "Missing plugins: ${remaining_missing_plugins_and_sources[*]}"
    return 1
  fi
  daemon.log_info "Added all missing plugins successfully"
  if [[ ${#remaining_changed_plugins_and_sources[@]} -gt 0 ]]; then
    daemon.log_error "Changed plugins: ${remaining_changed_plugins_and_sources[*]}"
    return 1
  fi
  daemon.log_info "Updated all changed plugins successfully"
  rm -rf "${plugins_dir}"
  mv "${tmp_plugins_dir}" "${plugins_dir}"
}
daemon.get_merged_asset_args() {
  local plugin_count="${1}"
  local plugin_index="${2}"
  local plugin_expanded_asset_args=($(echo "${3}" | xargs))
  local asset_args=($(echo "${4}" | xargs))
  local plugin_expanded_asset_arg_count="${#plugin_expanded_asset_args[@]}"
  plugin_expanded_asset_arg_count=$((plugin_expanded_asset_arg_count / 3))
  local grouped_plugin_expanded_asset_args=()
  local i=0
  for plugin_expanded_asset_arg in "${plugin_expanded_asset_args[@]}"; do
    if [[ $((i % 3)) -ne 0 ]]; then
      i=$((i + 1))
      continue
    fi
    local str=""
    str="${str} ${plugin_expanded_asset_args[${i}]}"
    str="${str} ${plugin_expanded_asset_args[$((i + 1))]}"
    str="${str} ${plugin_expanded_asset_args[$((i + 2))]}"
    grouped_plugin_expanded_asset_args+=("${str}")
    i=$((i + 1))
  done
  local grouped_plugin_expanded_asset_args_count="${#grouped_plugin_expanded_asset_args[@]}"
  if [[ ${grouped_plugin_expanded_asset_args_count} -ne ${plugin_count} ]]; then
    daemon.log_error "Unexpected - the number of expanded assets does not match the number of plugins (warning, you'll need coffee and bravery for this one)."
    return 1
  fi
  echo "${asset_args[*]}" "${grouped_plugin_expanded_asset_args[${plugin_index}]}" | xargs
}
daemon.validate_firejail_assets() {
  local asset_firejailed_path="${1}"
  local asset_host_path="${2}"
  local chmod_permission="${3}"
  if [[ -z "${asset_firejailed_path}" ]]; then
    daemon.log_error "Unexpected - empty firejailed path."
    return 1
  fi
  if [[ ! "${asset_firejailed_path}" =~ ^/ ]]; then
    daemon.log_error "Unexpected - firejailed path must start with a \"/\""
    return 1
  fi
  if [[ ! "${chmod_permission}" =~ ^[0-7]{3}$ ]]; then
    daemon.log_error "Unexpected - invalid chmod permission."
    return 1
  fi
  if [[ ! -e ${asset_host_path} ]]; then
    daemon.log_error "Unexpected - invalid asset host path."
    return 1
  fi
}
daemon.merge_fs() {
  local namespace="${1}"
  local partial_dir="${2}"
  local merged_dir="${3}"
  local partial_files=($(find "${partial_dir}" -type f | xargs))
  for partial_file in "${partial_files[@]}"; do
    local partial_file_dir="$(dirname "${partial_file}")"
    local partial_file_name="$(basename "${partial_file}")"
    local merged_relative_path="${partial_file_dir#${partial_dir}}"
    local merged_abs_dirpath="${merged_dir}${merged_relative_path}"
    mkdir -p "${merged_abs_dirpath}"
    local merged_file_path="${merged_abs_dirpath}/${namespace}-${partial_file_name}"
    cp "${partial_file}" "${merged_file_path}"
  done
}
daemon.expand_assets_to_thruples() {
  local expanded_asset=($(echo "${1}" | xargs))
  local expanded_asset_path="${2}"
  local expanded_asset_permission="${3}"
  local plugins=($(echo "${4}" | xargs))
  local plugin_names=($(daemon.plugin_paths_to_names "${plugins[*]}"))
  local expanded_asset_args=()
  local i=0
  for plugin in "${plugins[@]}"; do
    local plugin_expanded_asset="${expanded_asset[${i}]}"
    if [[ -z "${plugin_expanded_asset}" ]]; then
      expanded_asset_args+=("-" "-" "-")
      i=$((i + 1))
      continue
    fi
    expanded_asset_args+=(
      "${expanded_asset[${i}]}"
      "${expanded_asset_path}"
      "${expanded_asset_permission}"
    )
    i=$((i + 1))
  done
  echo "${plugins[*]}" | xargs
  echo "${plugin_names[*]}" | xargs
  echo "${expanded_asset_args[*]}" | xargs
}
daemon.run_in_firejail() {
  local phase="${1}"
  local phase_cache="${2}"
  local plugins=($(echo "${3}" | xargs))
  local asset_args=($(echo "${4}" | xargs))
  local plugin_expanded_asset_args=($(echo "${5}" | xargs))
  local executable_options=($(echo "${6}" | xargs))
  local merge_path="${7}"
  local firejail_options=($(echo "${8}" | xargs))
  local aggregated_stdout_file="$(mktemp)"
  local aggregated_stderr_file="$(mktemp)"
  local firejailed_pids=()
  local firejailed_home_dirs=()
  local plugin_stdout_files=()
  local plugin_stderr_files=()
  local plugin_index=0
  local plugin_count="${#plugins[@]}"
  for plugin_path in "${plugins[@]}"; do
    if [[ ! -x ${plugin_path}/plugin ]]; then
      daemon.log_error "Unexpected - ${plugin_path}/plugin is not an executable file."
      return 1
    fi
    local plugins_dir="$(dirname "${plugin_path}")"
    local plugin_name="$(daemon.plugin_paths_to_names "${plugins[${plugin_index}]}")"
    local plugin_phase_cache="${phase_cache}/${plugin_name}"
    mkdir -p "${plugin_phase_cache}"
    local merged_asset_args=($(
      daemon.get_merged_asset_args \
        "${plugin_count}" \
        "${plugin_index}" \
        "${plugin_expanded_asset_args[*]}" \
        "${asset_args[*]}"
    ))
    local merged_asset_arg_count="${#merged_asset_args[@]}"
    local firejailed_home_dir="$(mktemp -d)"
    local plugin_stdout_file="$(mktemp)"
    local plugin_stderr_file="$(mktemp)"
    local plugin_phase_cache="${phase_cache}/${plugin_name}"
    local firejailed_cache="${firejailed_home_dir}/cache"
    mkdir -p "${plugin_phase_cache}" "${firejailed_cache}"
    cp -rfa "${plugin_phase_cache}"/. "${firejailed_cache}/"
    chmod 777 "${firejailed_cache}"
    for ((i = 0; i < ${merged_asset_arg_count}; i++)); do
      if [[ $((i % 3)) -ne 0 ]]; then
        continue
      fi
      local asset_host_path="${merged_asset_args[${i}]}"
      local asset_firejailed_path="${merged_asset_args[$((i + 1))]}"
      local chmod_permission="${merged_asset_args[$((i + 2))]}"
      if [[ ${asset_firejailed_path} != "-" ]]; then
        if ! daemon.validate_firejail_assets \
          "${asset_firejailed_path}" \
          "${asset_host_path}" \
          "${chmod_permission}"; then
          return 1
        fi
        local asset_firejailed_path="${firejailed_home_dir}${asset_firejailed_path}"
        if [[ -f ${asset_host_path} ]]; then
          cp "${asset_host_path}" "${asset_firejailed_path}"
        elif [[ -d ${asset_host_path} ]]; then
          mkdir -p "${asset_firejailed_path}"
          if ! cp -rfa "${asset_host_path}"/. "${asset_firejailed_path}/"; then
            daemon.log_error "${phase} phase: failed to copy ${asset_host_path} to ${asset_firejailed_path}."
            return 1
          fi
        fi
        chmod -R "${chmod_permission}" "${asset_firejailed_path}"
      fi
    done
    cp -a "${plugin_path}/plugin" "${firejailed_home_dir}/plugin"
    local plugin_config_file="${plugin_path}/solos.config.json"
    if [[ -f ${plugin_config_file} ]]; then
      cp "${plugin_config_file}" "${firejailed_home_dir}/solos.config.json"
    else
      echo "{}" >"${firejailed_home_dir}/solos.config.json"
    fi
    if [[ -f ${daemon__manifest_file} ]]; then
      # TODO: make sure local plugins are included.
      cp "${daemon__manifest_file}" "${firejailed_home_dir}/solos.manifest.json"
    else
      return 1
    fi
    if [[ ! " ${executable_options[@]} " =~ " --phase-configure " ]]; then
      chmod 555 "${firejailed_home_dir}/solos.config.json"
    else
      chmod 777 "${firejailed_home_dir}/solos.config.json"
    fi
    firejail \
      --quiet \
      --noprofile \
      --private="${firejailed_home_dir}" \
      "${firejail_options[@]}" \
      /root/plugin "${executable_options[@]}" \
      >"${plugin_stdout_file}" 2>"${plugin_stderr_file}" &
    local firejailed_pid=$!
    firejailed_pids+=("${firejailed_pid}")
    firejailed_home_dirs+=("${firejailed_home_dir}")
    plugin_stdout_files+=("${plugin_stdout_file}")
    plugin_stderr_files+=("${plugin_stderr_file}")
    plugin_index=$((plugin_index + 1))
  done
  local firejailed_kills=""
  local firejailed_failures=0
  local i=0
  for firejailed_pid in "${firejailed_pids[@]}"; do
    wait "${firejailed_pid}"
    local firejailed_exit_code=$?
    local executable_path="${plugins[${i}]}/plugin"
    local plugin_name="$(daemon.plugin_paths_to_names "${plugins[${i}]}")"
    local firejailed_home_dir="${firejailed_home_dirs[${i}]}"
    # Make sure daemon can still do whatever it wants.
    chmod -R 777 "${firejailed_home_dir}"
    local plugin_stdout_file="${plugin_stdout_files[${i}]}"
    local plugin_stderr_file="${plugin_stderr_files[${i}]}"
    if [[ -f ${plugin_stdout_file} ]]; then
      while IFS= read -r line; do
        echo "(${plugin_name}) ${line}" >>"${aggregated_stdout_file}"
      done <"${plugin_stdout_file}"
    fi
    if [[ -f ${plugin_stderr_file} ]]; then
      while IFS= read -r line; do
        echo "(${plugin_name}) ${line}" >>"${aggregated_stderr_file}"
      done <"${plugin_stderr_file}"
    fi
    if [[ ${firejailed_exit_code} -ne 0 ]]; then
      daemon.log_warn "${phase} phase: ${executable_path} exited with status ${firejailed_exit_code}"
      firejailed_failures=$((firejailed_failures + 1))
    fi
    i=$((i + 1))
  done
  i=0
  for plugin_stderr_file in "${plugin_stderr_files[@]}"; do
    local plugin_name="$(daemon.plugin_paths_to_names "${plugins[${i}]}")"
    if grep -q "^SOLOS_PANIC" "${plugin_stderr_file}" >/dev/null 2>/dev/null; then
      firejailed_kills="${firejailed_kills} ${plugin_name}"
    fi
    i=$((i + 1))
  done
  firejailed_kills=($(echo "${firejailed_kills}" | xargs))
  for plugin_stdout_file in "${plugin_stdout_files[@]}"; do
    if grep -q "^SOLOS_PANIC" "${plugin_stdout_file}" >/dev/null 2>/dev/null; then
      daemon.log_warn "${phase} phase: the plugin sent a panic message to stderr."
    fi
  done
  if [[ ${firejailed_failures} -gt 0 ]]; then
    daemon.log_error "${phase} phase: there were ${firejailed_failures} total failures across ${plugin_count} plugins."
  fi
  if [[ ${#firejailed_kills[@]} -gt 0 ]]; then
    lib.panics_add "plugin_panics_detected" <<EOF
The following plugins panicked: [${firejailed_kills[*]}] in phase: ${phase}

Once all panic files in ${daemon__panics_dir} are removed (and hopefully resolved!), the daemon will restart all plugins from the beginning.

STDERR:
$(cat "${aggregated_stderr_file}")

STDOUT:
$(cat "${aggregated_stdout_file}")
EOF
    daemon.log_error "${phase} phase: panics detected from: ${firejailed_kills[*]}"
    echo "151"
    return 1
  else
    lib.panics_remove "plugin_panics_detected"
  fi
  local assets_created_by_plugins=()
  local i=0
  if [[ -n ${merge_path} ]]; then
    for firejailed_home_dir in "${firejailed_home_dirs[@]}"; do
      local plugin_name="${plugin_names[${i}]}"
      local created_asset="${firejailed_home_dir}${merge_path}"
      assets_created_by_plugins+=("${created_asset}")
      daemon.log_info "${phase} phase: an asset was created: ${created_asset}"
      rm -rf "${phase_cache}/${plugin_name}"
      mv "${firejailed_home_dir}/cache" "${phase_cache}/${plugin_name}"
      daemon.log_info "${phase} phase: saved cache to ${phase_cache}/${plugin_name}"
      i=$((i + 1))
    done
  fi
  echo "${aggregated_stdout_file}" | xargs
  echo "${aggregated_stderr_file}" | xargs
  echo "${assets_created_by_plugins[*]}" | xargs
}
# ------------------------------------------------------------------------
#
# ALL PHASES:
#
#-------------------------------------------------------------------------
# CONFIGURE:
# The configure phase is responsible for making any modifications to the config files associated
# with the plugins. This allows for a simple upgrade path for plugins that need to make changes
# to the way they configs are structured but don't want to depend on users to manually update them.
daemon.configure_phase() {
  local phase_cache="${1}"
  local returned="$(
    daemon.expand_assets_to_thruples \
      "" \
      "" \
      "" \
      "${2}"
  )"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-configure")
  local firejail_args=("--net=none")
  local asset_args=()
  returned="$(
    daemon.run_in_firejail \
      "configure" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/solos.config.json" \
      "${firejail_args[*]}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")" \
  local potentially_updated_configs=($(lib.line_to_args "${returned}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for potentially_updated_config_file in "${potentially_updated_configs[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    cp "${potentially_updated_config_file}" "${merge_dir}/${plugin_name}.json"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}" | xargs
  echo "${aggregated_stderr_file}" | xargs
  echo "${merge_dir}" | xargs
}
# DOWNLOAD:
# The download phase is where plugin authors can pull information from remote resources that they might
# need to process the user's data. This could be anything from downloading a file to making an API request.
daemon.download_phase() {
  local phase_cache="${1}"
  local returned="$(
    daemon.expand_assets_to_thruples \
      "" \
      "" \
      "" \
      "${2}"
  )"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-download")
  local firejail_args=()
  local asset_args=(
    "$(mktemp -d)" "/download" "777"
  )
  returned="$(
    daemon.run_in_firejail \
      "download" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/download" \
      "${firejail_args[*]}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  local download_dirs_created_by_plugins=($(lib.line_to_args "${returned}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for created_download_dir in "${download_dirs_created_by_plugins[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    daemon.merge_fs \
      "${plugin_name}" \
      "${created_download_dir}" \
      "${merge_dir}"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${merge_dir}"
  echo "${download_dirs_created_by_plugins[*]}"
}
# PROCESS:
# The process phase is where the bulk of the work is done This phase has access to the user's scrubbed data
# and the downloaded data from the download phase. During this phase, we cut off access to the network to
# prevent any data exfiltration.
daemon.process_phase() {
  local phase_cache="${1}"
  local scrubbed_dir="${2}"
  local merged_download_dir="${3}"
  local plugin_download_dirs=($(echo "${4}" | xargs))
  local returned="$(
    daemon.expand_assets_to_thruples \
      "${plugin_download_dirs[*]}" \
      "/download" \
      "555" \
      "${5}"
  )"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-process")
  local firejail_args=("--net=none")
  local asset_args=(
    "$(mktemp)" "/processed.json" "777"
    "${scrubbed_dir}" "/solos" "555"
    "${merged_download_dir}" "/plugins/download" "555"
  )
  returned="$(
    daemon.run_in_firejail \
      "process" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/processed.json" \
      "${firejail_args[*]}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  local processed_files_created_by_plugins=($(lib.line_to_args "${returned}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for processed_file in "${processed_files_created_by_plugins[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    cp "${processed_file}" "${merge_dir}/${plugin_name}.json"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${merge_dir}"
  echo "${processed_files_created_by_plugins[*]}"
}
# CHUNK:
# The chunking phase is where processed data gets converted into text chunks. This is useful when
# designing a RAG query system or a search index.
daemon.chunk_phase() {
  local phase_cache="${1}"
  local merged_processed_dir="${2}"
  local processed_files=("$(echo "${3}" | xargs)")
  local returned="$(
    daemon.expand_assets_to_thruples \
      "${processed_files[*]}" \
      "/processed.json" \
      "555" \
      "${4}"
  )"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-chunk")
  local firejail_args=()
  local asset_args=(
    "$(mktemp)" "/chunks.log" "777"
    "${merged_processed_dir}" "/plugins/processed" "555"
  )
  returned="$(
    daemon.run_in_firejail \
      "chunk" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "/chunks.log" \
      "${firejail_args[*]}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  local chunk_log_files_created_by_plugins=($(lib.line_to_args "${returned}" "2"))
  local merge_dir="$(mktemp -d)"
  local i=0
  for chunk_log_file in "${chunk_log_files_created_by_plugins[@]}"; do
    local plugin_name="${plugin_names[${i}]}"
    cp "${chunk_log_file}" "${merge_dir}/${plugin_name}.log"
    i=$((i + 1))
  done
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
  echo "${merge_dir}"
  echo "${chunk_log_files_created_by_plugins[*]}"
}
# PUBLISH:
# This phase is responsible for taking the chunks and publishing them to the appropriate remote
# service for custom use cases, such as SMS bots, email alerts, or a company-wide search index.
# Note: this phase doesn't need access to the processed data, only the chunks. This phase and the chunk
# phase have network access, so any kind of publishing that is specific to the processed data
# can be done in the chunk phase. I'm not merging the phases because I want the publish phase to allow
# plugin authors to use all chunks, regardless of which plugin created them.
daemon.publish_phase() {
  local phase_cache="${1}"
  local merged_chunks="${2}"
  local chunk_log_files=("$(echo "${3}" | xargs)")
  local returned="$(
    daemon.expand_assets_to_thruples \
      "${chunk_log_files[*]}" \
      "/chunks.log" \
      "555" \
      "${4}"
  )"
  local plugins=($(lib.line_to_args "${returned}" "0"))
  local plugin_names=($(lib.line_to_args "${returned}" "1"))
  local expanded_asset_args=($(lib.line_to_args "${returned}" "2"))
  local executable_options=("--phase-publish")
  local firejail_args=()
  local asset_args=(
    "${merged_chunks}" "/plugins/chunks" "555"
  )
  returned="$(
    daemon.run_in_firejail \
      "publish" \
      "${phase_cache}" \
      "${plugins[*]}" \
      "${asset_args[*]}" \
      "${expanded_asset_args[*]}" \
      "${executable_options[*]}" \
      "" \
      "${firejail_args[*]}"
  )"
  if [[ ${returned} =~ ^[0-9]+$ ]]; then
    return "${returned}"
  fi
  local aggregated_stdout_file="$(lib.line_to_args "${returned}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${returned}" "1")"
  echo "${aggregated_stdout_file}"
  echo "${aggregated_stderr_file}"
}
daemon.plugin_runner() {
  local plugins=($(echo "${1}" | xargs))

  # Prep the archive directory.
  # We'll build the archive directory continuously as we progress through the phases.
  # So if the daemon crashes, we'll have a snapshot of everything up to that point.
  local nano_seconds="$(date +%s%N)"
  local next_archive_dir="${HOME}/.solos/data/daemon/archives/${nano_seconds}"
  mkdir -p "${next_archive_dir}"
  mkdir -p "${next_archive_dir}/caches"
  local archive_log_file="${next_archive_dir}/dump.log"
  touch "${archive_log_file}"
  # Define cache directories.
  local configure_cache="${HOME}/.solos/data/daemon/cache/configure"
  local download_cache="${HOME}/.solos/data/daemon/cache/download"
  local process_cache="${HOME}/.solos/data/daemon/cache/process"
  local chunk_cache="${HOME}/.solos/data/daemon/cache/chunk"
  local publish_cache="${HOME}/.solos/data/daemon/cache/publish"
  mkdir -p "${configure_cache}" "${download_cache}" "${process_cache}" "${chunk_cache}" "${publish_cache}"
  if [[ ! -f ${daemon__manifest_file} ]]; then
    echo "[]" >"${daemon__manifest_file}"
  fi

  # Remove secrets from all files/dirs in the user's workspace.
  local scrubbed_dir="$(daemon.scrub)"
  if [[ -z ${scrubbed_dir} ]]; then
    daemon.log_error "Failed to scrub the mounted volume."
    return 1
  fi
  cp -r "${scrubbed_dir}" "${next_archive_dir}/scrubbed"
  daemon.log_info "Archived the scrubbed data at \"$(daemon.get_host_path "${next_archive_dir}/scrubbed")\""
  # ------------------------------------------------------------------------------------
  #
  # CONFIGURE PHASE:
  # Allow plugins to create a default config if none was provided, or modify the existing
  # one if it detects abnormalities.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  daemon.configure_phase \
    "${configure_cache}" \
    "${plugins[*]}" \
    >"${tmp_stdout}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  if [[ ${return_code} -ne 0 ]]; then
    daemon.log_error "The configure phase encoutered one or more non-fatal errors ${return_code}."
  else
    daemon.log_info "The configure phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_configure_dir="$(lib.line_to_args "${result}" "2")"
  daemon.stash_plugin_logs "configure" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  daemon.apply_config_updates "${merged_configure_dir}"
  daemon.log_info "Updated configs based on the configure phase."
  mkdir -p "${next_archive_dir}/configure" "${next_archive_dir}/caches/configure"
  cp -rfa "${merged_configure_dir}"/. "${next_archive_dir}/configure"/
  cp -rfa "${configure_cache}"/. "${next_archive_dir}/caches/configure"/
  daemon.log_info "Archived the configure data at \"$(daemon.get_host_path "${next_archive_dir}/configure")\""
  # ------------------------------------------------------------------------------------
  #
  # DOWNLOAD PHASE:
  # let plugins download anything they need before they gain access to the data.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  daemon.download_phase \
    "${download_cache}" \
    "${plugins[*]}" \
    >"${tmp_stdout}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  if [[ ${return_code} -ne 0 ]]; then
    daemon.log_error "The download phase encoutered one or more non-fatal errors ${return_code}."
  else
    daemon.log_info "The download phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_download_dir="$(lib.line_to_args "${result}" "2")"
  local plugin_download_dirs=($(lib.line_to_args "${result}" "3"))
  daemon.stash_plugin_logs "download" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  mkdir -p "${next_archive_dir}/download" "${next_archive_dir}/caches/download"
  cp -rfa "${merged_download_dir}"/. "${next_archive_dir}/download"/
  cp -rfa "${download_cache}"/. "${next_archive_dir}/caches/download"/
  daemon.log_info "Archived the download data at \"$(daemon.get_host_path "${next_archive_dir}/download")\""
  # ------------------------------------------------------------------------------------
  #
  # PROCESSOR PHASE:
  # Allow all plugins to access the collected data. Any one plugin can access the data
  # generated by another plugin. This is key to allow plugins to work together.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  daemon.process_phase \
    "${process_cache}" \
    "${scrubbed_dir}" \
    "${merged_download_dir}" \
    "${plugin_download_dirs[*]}" \
    "${plugins[*]}" \
    >"${tmp_stdout}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  if [[ ${return_code} -ne 0 ]]; then
    daemon.log_error "The process phase encoutered one or more non-fatal errors ${return_code}."
  else
    daemon.log_info "The process phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_processed_dir="$(lib.line_to_args "${result}" "2")"
  local plugin_processed_files=($(lib.line_to_args "${result}" "3"))
  daemon.stash_plugin_logs "process" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  mkdir -p "${next_archive_dir}/processed" "${next_archive_dir}/caches/process"
  cp -rfa "${merged_processed_dir}"/. "${next_archive_dir}/processed"/
  cp -rfa "${process_cache}"/. "${next_archive_dir}/caches/process"/
  daemon.log_info "Archived the processed data at \"$(daemon.get_host_path "${next_archive_dir}/processed")\""
  # ------------------------------------------------------------------------------------
  #
  # CHUNK PHASE:
  # Converts processed data into pure text chunks.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  daemon.chunk_phase \
    "${chunk_cache}" \
    "${merged_processed_dir}" \
    "${plugin_processed_files[*]}" \
    "${plugins[*]}" \
    >"${tmp_stdout}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  if [[ ${return_code} -ne 0 ]]; then
    daemon.log_error "The chunk phase encoutered one or more non-fatal errors ${return_code}."
  else
    daemon.log_info "The chunk phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  local merged_chunks_dir="$(lib.line_to_args "${result}" "2")"
  local plugin_chunk_files=($(lib.line_to_args "${result}" "3"))
  daemon.stash_plugin_logs "chunk" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  mkdir -p "${next_archive_dir}/chunks" "${next_archive_dir}/caches/chunk"
  cp -rfa "${merged_chunks_dir}"/. "${next_archive_dir}/chunks"/
  cp -rfa "${chunk_cache}"/. "${next_archive_dir}/caches/chunk"/
  daemon.log_info "Archived the chunk data at \"$(daemon.get_host_path "${next_archive_dir}/chunks")\""
  # ------------------------------------------------------------------------------------
  #
  # PUBLISH PHASE:
  # Any last second processing before the chunks are sent to a remote server,
  # third party LLM, local llm, vector db, etc. Ex: might want to use a low cost
  # LLM to generate keywords for chunks.
  #
  # ------------------------------------------------------------------------------------
  local tmp_stdout="$(mktemp)"
  daemon.publish_phase \
    "${publish_cache}" \
    "${merged_chunks_dir}" "${plugin_chunk_files[*]}" \
    "${plugins[*]}" \
    >"${tmp_stdout}"
  local return_code="$?"
  if [[ ${return_code} -eq 151 ]]; then
    return "${return_code}"
  fi
  if [[ ${return_code} -ne 0 ]]; then
    daemon.log_error "The publish phase encoutered one or more non-fatal errors ${return_code}."
  else
    daemon.log_info "The publish phase ran successfully."
  fi
  local result="$(cat "${tmp_stdout}" 2>/dev/null || echo "")"
  local aggregated_stdout_file="$(lib.line_to_args "${result}" "0")"
  local aggregated_stderr_file="$(lib.line_to_args "${result}" "1")"
  daemon.stash_plugin_logs "publish" "${archive_log_file}" "${aggregated_stdout_file}" "${aggregated_stderr_file}"
  mkdir -p "${next_archive_dir}/caches/publish"
  cp -r "${publish_cache}"/. "${next_archive_dir}/caches/publish"/
  daemon.log_info "Archival complete at \"$(daemon.get_host_path "${next_archive_dir}")\""
}
daemon.loop() {
  local is_precheck=true
  while true; do
    while true; do
      if [[ -z $(ls -A "${daemon__panics_dir}") ]]; then
        break
      else
        daemon.log_error "Panics detected. Waiting 5 seconds before checking again."
        sleep 5
      fi
    done
    if ! daemon.update_plugins; then
      daemon.log_error "Failed to apply the manifest. Waiting 20 seconds before the next run."
      sleep 20
      return 1
    fi
    plugins=()
    if [[ ${is_precheck} = true ]]; then
      plugins=($(daemon.plugin_names_to_paths "${daemon__precheck_plugin_names[*]}"))
    else
      local solos_plugin_names="$(daemon.get_solos_plugin_names)"
      local user_plugin_names="$(daemon.get_user_plugin_names)"
      local plugins=($(daemon.plugin_names_to_paths "${solos_plugin_names[*]} ${user_plugin_names[*]}" | xargs))
    fi
    [[ ${is_precheck} = true ]] && is_precheck=false || is_precheck=true
    if [[ ${#plugins[@]} -eq 0 ]]; then
      daemon.log_warn "No plugins were found. Waiting 20 seconds before the next run."
      sleep 20
      continue
    fi
    if [[ ${is_precheck} = false ]]; then
      daemon.log_info "Running precheck plugins."
      daemon.plugin_runner "${plugins[*]}"
      daemon.log_info "Archived phase results for precheck plugins at \"$(daemon.get_host_path "${archive_dir}")\""
      daemon.log_info "Prechecks passed."
    else
      daemon.log_info "Starting a new cycle."
      daemon.plugin_runner "${plugins[*]}"
      daemon.log_info "Archived phase results at \"$(daemon.get_host_path "${archive_dir}")\""
      daemon.log_info "Waiting for the next cycle."
      daemon__remaining_retries=5
      sleep 2
      daemon.handle_requests
    fi
    # No
    lib.panics_remove "daemon_too_many_retries"
  done
  return 0
}
daemon.retry() {
  daemon__remaining_retries=$((daemon__remaining_retries - 1))
  if [[ ${daemon__remaining_retries} -eq 0 ]]; then
    daemon.log_error "Killing the daemon due to too many failures."
    daemon.status "RUN_FAILED"
    lib.panics_add "daemon_too_many_retries" <<EOF
The daemon failed and exited after too many retries. Time of failure: $(date).
EOF
    exit 1
  fi
  daemon.status "RECOVERING"
  daemon.log_info "Restarting the daemon loop."
  daemon.loop
  daemon.retry
}
daemon() {
  # Requests are meant to fulfill at the top of the daemon loop only.
  # Ensure a previously fulfilled request is cleared.
  if rm -f "${daemon__request_file}"; then
    daemon.log_info "Cleared previous request file: \"$(daemon.get_host_path "${daemon__request_file}")\""
  else
    daemon.log_error "Failed to clear the previous request file: \"$(daemon.get_host_path "${daemon__request_file}")\""
    exit 1
  fi
  # If the daemon is already running, we should abort the launch.
  # Don't fuck with the status file. It pertains to the actually
  # running daemon process, so not this one.
  if [[ -n ${daemon__prev_pid} ]] && [[ ${daemon__prev_pid} -ne ${daemon__pid} ]]; then
    if ps -p "${daemon__prev_pid}" >/dev/null; then
      daemon.log_error "Aborting launch due to existing daemon process with pid: ${daemon__prev_pid}"
      exit 1
    fi
  fi
  # Store the current and valid PID in the pidfile.
  mkdir -p "${daemon__daemon_data_dir}"
  echo "${daemon__pid}" >"${daemon__pid_file}"
  # We like to see this when running "daemon status" in our shell.
  daemon.status "UP"
  # The main "loop" that churns through our plugins.
  daemon.loop
  # We define some number of allowed retry attempts in a global var
  # and panic if we were not able to restart the loop.
  daemon.retry
}

daemon
