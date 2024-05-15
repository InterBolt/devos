#!/usr/bin/env bash

vSELF_PKG_GUM_PKG_DIR="$(dirname "$0")"
vSELF_PKG_GUM_RELEASES_DIRNAME=".installs"

__gum__fn__get_release_file() {
  local gum_version="0.13.0"
  local gum_release_url="https://github.com/charmbracelet/gum/releases/download"
  local release=""
  if [[ $(uname) = 'Darwin' ]]; then
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Darwin_arm64.tar.gz"
    else
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Darwin_x86_64.tar.gz"
    fi
  else
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Linux_arm64.tar.gz"
    else
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Linux_x86_64.tar.gz"
    fi
  fi
  echo "${release}"
}

gum_install() {
  local release="$(__gum__fn__get_release_file)"
  local release_download_dirname="$(basename "${release}" | sed 's/.tar.gz//')"
  local location_dir="${vSELF_PKG_GUM_PKG_DIR}/${vSELF_PKG_GUM_RELEASES_DIRNAME}/${release_download_dirname}"
  mkdir -p "${location_dir}"
  if [[ ! -f ${location_dir}/gum ]]; then
    curl -L --silent --show-error "${release}" | tar -xz -C "${location_dir}"
  fi
  echo "${location_dir}/gum"
}

gum_bin() {
  local executable_path="$(gum_install)"
  if [[ -f ${executable_path} ]]; then
    "${executable_path}" "$@"
  else
    echo "failed to install gum" >&2
    exit 1
  fi
}

gum_github_token() {
  gum_bin input --password --placeholder "Enter Github access token:"
}

gum_github_email() {
  gum_bin input --placeholder "Enter Github email:"
}

gum_github_name() {
  gum_bin input --placeholder "Enter Github username:"
}

gum_repo_url() {
  gum_bin input --placeholder "Provide a github repo url:"
}

gum_confirm_new_app() {
  local project_name="$1"
  local project_app="$2"
  if gum_bin confirm \
    "Are you sure you want to create a new app called \`${project_app}\` in the project \`${project_name}\`?" \
    --affirmative="Yes" \
    --negative="No, exit without creating the app."; then
    echo "true"
  else
    echo "false"
  fi
}

gum_danger_box() {
  local terminal_width=$(tput cols)
  gum_bin style \
    --foreground "#F02" --border-foreground "#F02" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}

gum_success_box() {
  local terminal_width=$(tput cols)
  gum_bin style \
    --foreground "#0F0" --border-foreground "#0F0" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}
