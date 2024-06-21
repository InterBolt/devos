#!/usr/bin/env bash

. "${HOME}/.solos/repo/shared/lib.sh" || exit 1
. "${HOME}/.solos/repo/shared/log.sh" || exit 1
. "${HOME}/.solos/repo/shared/gum.sh" || exit 1

bashrc_github__config_path="${HOME}/.solos/config"
bashrc_github__secrets_path="${HOME}/.solos/secrets"

bashrc_github.print_help() {
  cat <<EOF

USAGE: github

DESCRIPTION:

Setup git using the Github CLI.

NOTES:

(1) You only need to run this once. Subsequent sessions will use the stored Github token, email, and name.
(2) Re-running it allows you to update the stored values.
EOF
}

bashrc_github._gh_token() {
  local tmp_file="$1"
  local gh_token="$(gum.github_token)"
  if [[ -z ${gh_token} ]]; then
    return 1
  fi
  echo "${gh_token}" >"${tmp_file}"
  if gh auth login --with-token <"${tmp_file}" >/dev/null; then
    bashrc.log_info "Updated Github token."
  else
    bashrc.log_error "Failed to authenticate with: ${gh_token}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      bashrc_github._gh_token "${tmp_file}"
    else
      bashrc.log_error "Exiting the setup process."
      return 1
    fi
  fi
}
bashrc_github._gh_email() {
  local tmp_file="$1"
  local github_email="$(gum.github_email)"
  if [[ -z ${github_email} ]]; then
    return 1
  fi
  echo "${github_email}" >"${tmp_file}"
  if git config --global user.email "${github_email}"; then
    bashrc.log_info "Updated git email."
  else
    bashrc.log_error "Failed to update git user.email to: ${github_email}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      bashrc_github._gh_email "${tmp_file}"
    else
      bashrc.log_error "Exiting the setup process."
      return 1
    fi
  fi
}
bashrc_github._gh_name() {
  local tmp_file="$1"
  local github_name="$(gum.github_name)"
  if [[ -z ${github_name} ]]; then
    return 1
  fi
  echo "${github_name}" >"${tmp_file}"
  if git config --global user.name "${github_name}"; then
    bashrc.log_info "Updated git name."
  else
    bashrc.log_error "Failed to update git user.name to: ${github_name}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      bashrc_github._gh_name "${tmp_file}"
    else
      return 1
    fi
  fi
}
bashrc_github.prompts() {
  mkdir -p "${bashrc_github__secrets_path}" "${bashrc_github__config_path}"
  local gh_token_path="${bashrc_github__secrets_path}/gh_token"
  local gh_name_path="${bashrc_github__config_path}/gh_name"
  local gh_email_path="${bashrc_github__config_path}/gh_email"
  if ! bashrc_github._gh_token "${gh_token_path}"; then
    bashrc.log_error "Failed to get Github token."
    return 1
  fi
  if ! bashrc_github._gh_email "${gh_email_path}"; then
    bashrc.log_error "Failed to get Github email."
    return 1
  fi
  if ! bashrc_github._gh_name "${gh_name_path}"; then
    bashrc.log_error "Failed to get Github name."
    return 1
  fi
}
bashrc_github.install() {
  mkdir -p "${bashrc_github__secrets_path}" "${bashrc_github__config_path}"
  local gh_token_path="${bashrc_github__secrets_path}/gh_token"
  local gh_name_path="${bashrc_github__config_path}/gh_name"
  local gh_email_path="${bashrc_github__config_path}/gh_email"
  local gh_token="$(cat "${gh_token_path}" 2>/dev/null || echo "")"
  local gh_email="$(cat "${gh_email_path}" 2>/dev/null || echo "")"
  local gh_name="$(cat "${gh_name_path}" 2>/dev/null || echo "")"
  if [[ -z "${gh_token}" ]]; then
    return 1
  fi
  if [[ -z "${gh_email}" ]]; then
    return 1
  fi
  if [[ -z "${gh_name}" ]]; then
    return 1
  fi
  if ! git config --global user.name "${gh_name}"; then
    bashrc.log_error "Failed to set git user.name."
    return 1
  else
    bashrc.log_info "Set git user.name to: ${gh_name}"
  fi
  if ! git config --global user.email "${gh_email}"; then
    bashrc.log_error "Failed to set git user.email."
    return 1
  else
    bashrc.log_info "Set git user.email to: ${gh_email}"
  fi
  if ! gh auth login --with-token <"${gh_token_path}"; then
    bashrc.log_error "Github CLI failed to authenticate."
    return 1
  else
    bashrc.log_info "Github CLI authenticated."
  fi
  if ! gh auth setup-git; then
    bashrc.log_error "Github CLI failed to setup."
    return 1
  else
    bashrc.log_info "Github CLI setup complete."
  fi
}
bashrc_github.main() {
  mkdir -p "${bashrc_github__secrets_path}" "${bashrc_github__config_path}"
  if bashrc.is_help_cmd "$1"; then
    bashrc_github.print_help
    return 0
  fi
  local return_file="$(mktemp)"
  if ! bashrc_github.prompts; then
    return 1
  fi
  if bashrc_github.install; then
    bashrc.log_info "Github CLI setup complete."
    return 0
  else
    return 1
  fi
}
