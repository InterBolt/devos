#!/usr/bin/env bash

daemon_scrub__users_home_dir="$(cat "${HOME}/.solos/data/store/users_home_dir" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon_scrub__checked_out_project="$(cat "${HOME}/.solos/data/store/checked_out_project" 2>/dev/null || echo "" | head -n 1 | xargs)"
daemon_scrub__project_dir="/root/.solos/projects/${daemon_scrub__checked_out_project}"

daemon_scrub.log_info() {
  local message="(SCRUB) ${1} pid=\"${daemon__pid}\""
  shift
  log_info "${message}" "$@"
}
daemon_scrub.log_error() {
  local message="(SCRUB) ${1} pid=\"${daemon__pid}\""
  shift
  log_error "${message}" "$@"
}
daemon_scrub.log_warn() {
  local message="(SCRUB) ${1} pid=\"${daemon__pid}\""
  shift
  log_warn "${message}" "$@"
}

# A little extra validation before we start copying stuff around.
daemon_scrub.project_dir_exists() {
  if [[ -z ${daemon_scrub__checked_out_project} ]]; then
    daemon_scrub.log_error "No project is checked out. Cannot determine which project to include in the daemon's copied .solos directory."
    return 1
  fi
  if [[ ! -d ${daemon_scrub__project_dir} ]]; then
    daemon_scrub.log_error "The checked out project directory does not exist: \"${daemon_scrub__users_home_dir}/.solos/projects/${daemon_scrub__checked_out_project}\""
    return 1
  fi
}
# Create a copy of the entire .solos directory minus projects that are not the checked out project.
# Copy and echo tmp dir only.
daemon_scrub.copy_to_tmp() {
  local tmp_dir="$(mktemp -d)"
  if [[ -z ${tmp_dir} ]]; then
    daemon_scrub.log_error "Failed to create a temporary directory for the safe copy."
    return 1
  fi
  if ! mkdir -p "${tmp_dir}/projects/${daemon_scrub__checked_out_project}"; then
    daemon_scrub.log_error "Failed to create the projects directory in the temporary directory."
    return 1
  fi
  if ! cp -r "${daemon_scrub__project_dir}/." "${tmp_dir}/projects/${daemon_scrub__checked_out_project}"; then
    daemon_scrub.log_error "Failed to copy the project directory: \"${daemon_scrub__project_dir}\" to: \"${tmp_dir}/projects/${daemon_scrub__checked_out_project}\""
    return 1
  fi
  local root_paths="$(find /root/.solos -maxdepth 1)"
  for root_path in ${root_paths[@]}; do
    local base="$(basename "${root_path}")"
    # Ensure that plugins don't need target any project in particular. Instead they can just do their thing
    # against all projects and we'll make sure that "all projects" is really just the checked out project.
    if [[ ${base} == "projects" ]]; then
      continue
    fi
    if [[ ${base} == ".solos" ]]; then
      continue
    fi
    if ! mkdir -p "${tmp_dir}/${base}"; then
      daemon_scrub.log_error "Failed to create the directory: \"${tmp_dir}/${base}\""
      return 1
    fi
    if [[ -d ${root_path} ]]; then
      if ! cp -r "${root_path}/." "${tmp_dir}/${base}"; then
        daemon_scrub.log_error "Failed to copy: \"${root_path}\" to: \"${tmp_dir}/${base}\""
        return 1
      fi
    else
      if ! cp "${root_path}" "${tmp_dir}/${base}"; then
        daemon_scrub.log_error "Failed to copy: \"${root_path}\" to: \"${tmp_dir}/${base}\""
        return 1
      fi
    fi
  done
  echo "${tmp_dir}"
}
daemon_scrub.remove_ssh() {
  local tmp_dir="${1}"
  local ssh_dirpaths="$(find "${tmp_dir}" -type d -name ".ssh")"
  for ssh_dirpath in ${ssh_dirpaths[@]}; do
    if ! rm -rf "${ssh_dirpath}"; then
      daemon_scrub.log_error "Failed to remove the SSH directory: \"${ssh_dirpath}\" from the temporary directory."
      return 1
    fi
  done

  # Yeah, yeah, this is dumb but I'd just repeat myself than use a harder to read regex or something.
  local ssh_dirpaths="$(find "${tmp_dir}" -type d -name "ssh")"
  for ssh_dirpath in ${ssh_dirpaths[@]}; do
    if ! rm -rf "${ssh_dirpath}"; then
      daemon_scrub.log_error "Failed to remove the SSH directory: \"${ssh_dirpath}\" from the temporary directory."
      return 1
    fi
  done
}
# Scrub all secrets, even those associated with non-checked out projects.
# Rather than relying on our due diligence to not include project-specific secrets
# in global directories, just make sure we scrub everything for extra safety.
daemon_scrub.scrub_secrets() {
  local tmp_dir="${1}"

  # The goal is to populate these arrays.
  local secret_filepaths=()
  local secrets=()

  # First up, the global secrets.
  local global_secret_filepaths="$(find /root/.solos/secrets -maxdepth 1)"
  for global_secret_filepath in ${global_secret_filepaths[@]}; do
    if [[ -d ${global_secret_filepath} ]]; then
      continue
    fi
    secret_filepaths+=("${global_secret_filepath}")
  done

  # Find all the secret files in each project and associated apps.
  local project_paths="$(find /root/.solos/projects -maxdepth 1)"
  for project_path in ${project_paths[@]}; do
    local project_secrets_path="${project_path}/secrets"
    if [[ ! -d ${project_secrets_path} ]]; then
      continue
    fi
    local project_secret_filepaths="$(find "${project_secrets_path}" -maxdepth 1)"
    for project_secret_filepath in ${project_secret_filepaths[@]}; do
      if [[ -d ${project_secret_filepath} ]]; then
        continue
      fi
      secret_filepaths+=("${project_secret_filepath}")
    done
    # WARNING: don't ever be clever and assume that any app/secrets dir is a SolOS secrets dir.
    # better to assume the user is handling that somehow themselves.
  done

  # First, look for any .env.* files across all of .solos and extract the secrets.
  # Note: we still want to encourage users to use the secrets directory for secrets, but I think
  # being extra cautious doesn't hurt and could save someone's ass.
  # An alternative is to blanket remove anything in a .gitignore file but I wonder if that will
  # constrain our plugins too much since there could be useful artifacts that we end up stripping away.
  local env_filepaths="$(find /root/.solos -type f -name ".env"*)"
  for env_filepath in ${env_filepaths[@]}; do
    # Filter away comments, blank lines, and then strip quotations.
    local env_secrets="$(cat "${env_filepath}" | grep -v '^#' | grep -v '^$' | sed 's/^[^=]*=//g' | sed 's/"//g' | sed "s/'//g" | xargs)"
    for env_secret in ${env_secrets[@]}; do
      secrets+=("${env_secret}")
    done
  done

  # Now loop through the secret files. Each secret file is guaranteed to only contain
  # it's secret contents on the first line.
  for secret_filepath in "${secret_filepaths[@]}"; do
    secrets+=("$(cat "${secret_filepath}" 2>/dev/null || echo "" | head -n 1)")
  done

  # Do the scrubbing:
  # - grep efficiently narrows down the files to the ones that contain the secret.
  # - sed does the actually replacement/scrubbing.
  for secret in "${secrets[@]}"; do
    if ! grep -rl "${secret}" "${tmp_dir}" | xargs sed -i "s/${secret}/SOLOS_REDACTED/g"; then
      daemon_scrub.log_error "Failed to scrub secret: \"${secret}\" from the temporary directory."
      return 1
    fi
  done
}
# Validate, copy, scrub, and echo the tmp dir path.
daemon_scrub.main() {
  if ! daemon_scrub.project_dir_exists; then
    return 1
  fi
  local tmp_dir="$(daemon_scrub.copy_to_tmp)"
  if [[ ! -d ${tmp_dir} ]]; then
    return 1
  fi
  daemon_scrub.log_info "Created a safe copy of the .solos directory at: ${tmp_dir}"
  if ! daemon_scrub.remove_ssh "${tmp_dir}"; then
    return 1
  fi
  daemon_scrub.log_info "Removed SSH keys from the safe copy."
  if ! daemon_scrub.scrub_secrets "${tmp_dir}"; then
    return 1
  fi
  daemon_scrub.log_info "Scrubbed secrets from the safe copy."
  echo "${tmp_dir}"
}
