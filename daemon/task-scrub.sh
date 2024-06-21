#!/usr/bin/env bash

. "${HOME}/.solos/repo/shared/lib.sh" || exit 1
. "${HOME}/.solos/repo/daemon/shared.sh" || exit 1

task_scrub__users_home_dir="$(lib.home_dir_path)"
task_scrub__checked_out_project="$(lib.checked_out_project)"
task_scrub__project_dir="/root/.solos/projects/${task_scrub__checked_out_project}"
task_scrub__suspect_extensions=(
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

trap 'rm -rf /root/.solos/data/daemon/tmp' EXIT

# A little extra validation before we start copying stuff around.
task_scrub.project_dir_exists() {
  if [[ -z ${task_scrub__checked_out_project} ]]; then
    shared.log_error "Unexpected error - no project is checked out."
    return 1
  fi
  if [[ ! -d ${task_scrub__project_dir} ]]; then
    shared.log_error "Unexpected error - \"${task_scrub__project_dir}\" does not exist."
    return 1
  fi
}
# Create a copy of the entire .solos directory minus projects that are not the checked out project.
# Copy and echo tmp dir only.
task_scrub.copy_to_tmp() {
  local cp_tmp_dir="$(mktemp -d)"
  local tmp_dir="/root/.solos/data/daemon/tmp"
  if rm -rf "${tmp_dir}"; then
    shared.log_info "Prepared - cleared the previous temporary directory: \"${tmp_dir}\""
  fi
  mkdir -p "${tmp_dir}"
  if [[ -z ${tmp_dir} ]]; then
    shared.log_error "Unexpected error - failed to create a temporary directory for the safe copy."
    return 1
  fi
  if ! mkdir -p "${cp_tmp_dir}/projects/${task_scrub__checked_out_project}"; then
    shared.log_error "Unexpected error - failed to create the projects directory in the temporary directory."
    return 1
  fi
  if ! cp -r "${task_scrub__project_dir}/." "${cp_tmp_dir}/projects/${task_scrub__checked_out_project}"; then
    shared.log_error "Unexpected error - failed to copy the project directory: \"${task_scrub__project_dir}\" to: \"${tmp_dir}/projects/${task_scrub__checked_out_project}\""
    return 1
  fi
  local root_paths="$(find /root/.solos -maxdepth 1)"
  for root_path in ${root_paths[@]}; do
    local base="$(basename "${root_path}")"
    if [[ ${base} = "projects" ]]; then
      continue
    fi
    if [[ ${base} = ".solos" ]]; then
      continue
    fi
    if ! mkdir -p "${cp_tmp_dir}/${base}"; then
      shared.log_error "Unexpected error - failed to create the directory: \"${cp_tmp_dir}/${base}\""
      return 1
    fi
    if [[ -d ${root_path} ]]; then
      if ! cp -r "${root_path}/." "${cp_tmp_dir}/${base}"; then
        shared.log_error "Unexpected error - failed to copy: \"${root_path}\" to: \"${cp_tmp_dir}/${base}\""
        return 1
      fi
    else
      if ! cp "${root_path}" "${cp_tmp_dir}/${base}"; then
        shared.log_error "Unexpected error - failed to copy: \"${root_path}\" to: \"${cp_tmp_dir}/${base}\""
        return 1
      fi
    fi
  done
  local random_dirname="$(date +%s | sha256sum | base64 | head -c 32)"
  mv "${cp_tmp_dir}" "${tmp_dir}/${random_dirname}"
  echo "${tmp_dir}/${random_dirname}"
}
# Anything that looks like an SSH key directory is removed.
task_scrub.remove_ssh() {
  local tmp_dir="${1}"
  local ssh_dirpaths="$(find "${tmp_dir}" -type d -name ".ssh" -o -name "ssh")"
  for ssh_dirpath in ${ssh_dirpaths[@]}; do
    if ! rm -rf "${ssh_dirpath}"; then
      shared.log_error "Unexpected error - failed to remove the SSH directory: \"${ssh_dirpath}\" from the temporary directory."
      return 1
    fi
    shared.log_info "Deleted - \"${ssh_dirpath}\""
  done
}
task_scrub.remove_suspect_secretfiles() {
  local tmp_dir="${1}"
  local find_args=()
  for suspect_extension in "${task_scrub__suspect_extensions[@]}"; do
    if [[ ${#find_args[@]} -eq 0 ]]; then
      find_args+=("-name" "*.${suspect_extension}")
      continue
    fi
    find_args+=("-o" "-name" "*.${suspect_extension}")
  done
  local secret_filepaths="$(find "${tmp_dir}" -type f "${find_args[@]}")"
  for secret_filepath in ${secret_filepaths[@]}; do
    if ! rm -f "${secret_filepath}"; then
      shared.log_error "Unexpected error - failed to remove the suspect secret file: \"${secret_filepath}\" from the temporary directory."
      return 1
    fi
    shared.log_info "Deleted - \"${secret_filepath}\""
  done
}
task_scrub.remove_gitignored_paths() {
  local tmp_dir="${1}"
  local git_dirs="$(find "${tmp_dir}" -type d -name ".git")"
  for git_dir in ${git_dirs[@]}; do
    local git_project_path="$(dirname "${git_dir}")"
    local gitignore_path="${git_project_path}/.gitignore"
    if [[ ! -f "${gitignore_path}" ]]; then
      shared.log_warn "Skipping - no .gitignore file found in git repo: \"${git_project_path}\""
      continue
    fi
    local gitignored_paths_to_delete="$(git -C "${git_project_path}" status -s --ignored | grep "^\!\!" | cut -d' ' -f2 | xargs)"
    for gitignored_path_to_delete in ${gitignored_paths_to_delete}; do
      gitignored_path_to_delete="${git_project_path}/${gitignored_path_to_delete}"
      if ! rm -rf "${gitignored_path_to_delete}"; then
        shared.log_error "Unexpected error - \"${gitignored_path_to_delete}\" from the temporary directory."
        return 1
      fi
      shared.log_info "Deleted - \"${gitignored_path_to_delete}\""
    done
  done
}
task_scrub.scrub_secrets() {
  local tmp_dir="${1}"
  local secrets=()

  # Extract global secrets.
  local global_secret_filepaths="$(find "${tmp_dir}"/secrets -maxdepth 1)"
  local i=0
  for global_secret_filepath in ${global_secret_filepaths[@]}; do
    if [[ -d ${global_secret_filepath} ]]; then
      continue
    fi
    secrets+=("$(cat "${global_secret_filepath}" 2>/dev/null || echo "" | head -n 1)")
    i=$((i + 1))
  done
  shared.log_info "Found - extracted ${i} secrets in global secret dir: ${tmp_dir}/secrets"

  # Extract project secrets.
  local project_paths="$(find "${tmp_dir}"/projects -maxdepth 1)"
  for project_path in ${project_paths[@]}; do
    local project_secrets_path="${project_path}/secrets"
    if [[ ! -d ${project_secrets_path} ]]; then
      continue
    fi
    local project_secret_filepaths="$(find "${project_secrets_path}" -maxdepth 1)"
    local i=0
    for project_secret_filepath in ${project_secret_filepaths[@]}; do
      if [[ -d ${project_secret_filepath} ]]; then
        continue
      fi
      secrets+=("$(cat "${project_secret_filepath}" 2>/dev/null || echo "" | head -n 1)")
      i=$((i + 1))
    done
    shared.log_info "Found - extracted ${i} secrets in project secret dir: ${project_secrets_path}"
  done

  # Extract .env secrets.
  local env_filepaths="$(find "${tmp_dir}" -type f -name ".env"* -o -name ".env")"
  for env_filepath in ${env_filepaths[@]}; do
    local env_secrets="$(cat "${env_filepath}" | grep -v '^#' | grep -v '^$' | sed 's/^[^=]*=//g' | sed 's/"//g' | sed "s/'//g" | xargs)"
    local i=0
    for env_secret in ${env_secrets[@]}; do
      secrets+=("${env_secret}")
      i=$((i + 1))
    done
    shared.log_info "Found - extracted ${i} secrets from file: ${env_filepath}"
  done

  # Remove duplicates and scrub.
  secrets=($(printf "%s\n" "${secrets[@]}" | sort -u))
  for secret in "${secrets[@]}"; do
    input_files=$(grep -rl "${secret}" "${tmp_dir}")
    if [[ -z ${input_files} ]]; then
      continue
    fi
    while IFS= read -r input_file; do
      if ! sed -E -i "s@${secret}@[REDACTED]@g" "${input_file}"; then
        shared.log_error "Unexpected error - \"${secret}\" from ${input_file}."
        return 1
      fi
    done <<<"${input_files}"
    shared.log_info "Scrubbed - \"${secret}\""
  done
}
task_scrub.main() {
  if ! task_scrub.project_dir_exists; then
    return 1
  fi
  local tmp_dir="$(task_scrub.copy_to_tmp)"
  if [[ ! -d ${tmp_dir} ]]; then
    return 1
  fi
  shared.log_info "Preparing - copied solos to: ${tmp_dir}"
  if ! task_scrub.remove_gitignored_paths "${tmp_dir}"; then
    return 1
  fi
  shared.log_info "Cleaned - removed gitignored paths from: ${tmp_dir}"
  if ! task_scrub.remove_ssh "${tmp_dir}"; then
    return 1
  fi
  shared.log_info "Cleaned - removed SSH directories from: ${tmp_dir}"
  if ! task_scrub.remove_suspect_secretfiles "${tmp_dir}"; then
    return 1
  fi
  shared.log_info "Cleaned - deleted potentially sensitive files based on an extension blacklist."
  if ! task_scrub.scrub_secrets "${tmp_dir}"; then
    return 1
  fi
  shared.log_info "Complete - scrubbed known secrets."
  echo "${tmp_dir}"
}
