#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/src/shared/log.sh" || exit 1
. "${HOME}/.solos/src/shared/gum.sh" || exit 1

bashrc_github.print_help() {
  cat <<EOF

USAGE: github

DESCRIPTION:

Setup git using the Github CLI.
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
    log.info "Updated Github token."
  else
    log.error "Failed to authenticate with: ${gh_token}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      bashrc_github._gh_token "${tmp_file}"
    else
      log.error "Exiting the setup process."
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
    log.info "Updated git email."
  else
    log.error "Failed to update git user.email to: ${github_email}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      bashrc_github._gh_token "${tmp_file}"
    else
      log.error "Exiting the setup process."
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
    log.info "Updated git name."
  else
    log.error "Failed to update git user.name to: ${github_name}"
    local should_retry="$(gum.confirm_retry)"
    if [[ ${should_retry} = true ]]; then
      echo "" >"${tmp_file}"
      bashrc_github._gh_token "${tmp_file}"
    else
      return 1
    fi
  fi
}
bashrc_github.prompts() {
  local tmp_gh_token_file="$(mktemp)"
  local tmp_gh_email_file="$(mktemp)"
  local tmp_gh_name_file="$(mktemp)"
  if ! bashrc_github._gh_token "${tmp_gh_token_file}"; then
    return 1
  fi
  if ! bashrc_github._gh_email "${tmp_gh_email_file}"; then
    return 1
  fi
  if ! bashrc_github._gh_name "${tmp_gh_name_file}"; then
    return 1
  fi
  echo "${tmp_gh_token_file}" "${tmp_gh_email_file}" "${tmp_gh_name_file}"
}
bashrc_github.main() {
  local config_path="${HOME}/.solos/config"
  local secrets_path="${HOME}/.solos/secrets"
  mkdir -p "${secrets_path}" "${config_path}"
  if [[ $# -eq 0 ]]; then
    bashrc_github.print_help
    return 0
  fi
  if bashrc.is_help_cmd "$1"; then
    bashrc_github.print_help
    return 0
  fi
  local return_file="$(mktemp)"
  if ! bashrc_github.prompts >"${return_file}"; then
    return 1
  fi
  local tmp_gh_token_path="$(lib.line_to_args "${return_file}" "0")"
  local tmp_gh_email_path="$(lib.line_to_args "${return_file}" "1")"
  local tmp_gh_name_path="$(lib.line_to_args "${return_file}" "2")"
  local gh_token_path="${secrets_path}/gh_token"
  local gh_name_path="${config_path}/gh_name"
  local gh_email_path="${config_path}/gh_email"
  rm -f "${secrets_path}/gh_token"
  mv "${tmp_gh_token_path}" "${secrets_path}/gh_token"
  rm -f "${config_path}/gh_email" "${config_path}/gh_name"
  mv "${tmp_gh_email_path}" "${config_path}/gh_email"
  mv "${tmp_gh_name_path}" "${config_path}/gh_name"
  if ! git config --global user.name "$(cat "${gh_name_path}")"; then
    log.error "Failed to set git user.name."
    return 1
  fi
  if ! git config --global user.email "$(cat "${gh_email_path}")"; then
    log.error "Failed to set git user.email."
    return 1
  fi
  if ! gh auth login --with-token <"${gh_token_path}"; then
    log.error "Github CLI failed to authenticate."
    return 1
  fi
  if ! gh auth setup-git; then
    log.error "Github CLI failed to setup."
    return 1
  fi
}
