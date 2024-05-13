#!/usr/bin/env bash

vSELF_PKG_GUM_ENTRY_DIR="${PWD}"
vSELF_PKG_GUM_PKG_DIR="${vSELF_PKG_GUM_ENTRY_DIR}/pkg"
vSELF_PKG_GUM_RELEASES_DIRNAME=".installs"
vSELF_PKG_GUM_VERSION="0.13.0"
vSELF_PKG_GUM_RELEASES_URL="https://github.com/charmbracelet/gum/releases/download"

if [[ ! -d ${vSELF_PKG_GUM_PKG_DIR} ]]; then
  echo "Failed to find bin/pkg directory. Cannot install gum" >&2
  exit 1
fi

pkg.gum._get_release_download_url() {
  local release=""
  if [[ $(uname) = 'Darwin' ]]; then
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${vSELF_PKG_GUM_RELEASES_URL}/v${vSELF_PKG_GUM_VERSION}/gum_${vSELF_PKG_GUM_VERSION}_Darwin_arm64.tar.gz"
    else
      release="${vSELF_PKG_GUM_RELEASES_URL}/v${vSELF_PKG_GUM_VERSION}/gum_${vSELF_PKG_GUM_VERSION}_Darwin_x86_64.tar.gz"
    fi
  else
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${vSELF_PKG_GUM_RELEASES_URL}/v${vSELF_PKG_GUM_VERSION}/gum_${vSELF_PKG_GUM_VERSION}_Linux_arm64.tar.gz"
    else
      release="${vSELF_PKG_GUM_RELEASES_URL}/v${vSELF_PKG_GUM_VERSION}/gum_${vSELF_PKG_GUM_VERSION}_Linux_x86_64.tar.gz"
    fi
  fi
  echo "${release}"
}

pkg.gum.install() {
  local release="$(pkg.gum._get_release_download_url)"
  local release_download_dirname="$(basename "${release}" | sed 's/.tar.gz//')"
  local location_dir="${vSELF_PKG_GUM_PKG_DIR}/${vSELF_PKG_GUM_RELEASES_DIRNAME}/${release_download_dirname}"
  mkdir -p "${location_dir}"
  if [[ ! -f ${location_dir}/gum ]]; then
    curl -L --silent --show-error "${release}" | tar -xz -C "${location_dir}"
  fi
  echo "${location_dir}/gum"
}

pkg.gum() {
  local executable_path="$(pkg.gum.install)"
  if [[ -f ${executable_path} ]]; then
    "${executable_path}" "$@"
  else
    echo "failed to install gum" >&2
    exit 1
  fi
}

pkg.gum.github_token() {
  pkg.gum input --password --placeholder "Enter Github access token:"
}

pkg.gum.github_email() {
  pkg.gum input --placeholder "Enter Github email:"
}

pkg.gum.github_name() {
  pkg.gum input --placeholder "Enter Github username:"
}

pkg.gum.repo_url() {
  pkg.gum input --placeholder "Provide a github repo url:"
}

pkg.gum.confirm_new_app() {
  local project_name="$1"
  local project_app="$2"
  if pkg.gum confirm \
    --prompt.align left \
    "Are you sure you want to create a new app called \`${project_app}\` in the project \`${project_name}\`?" \
    --affirmative="Yes" \
    --negative="No, exit without creating the app."; then
    echo "true"
  else
    echo "false"
  fi
}

pkg.gum.danger_box() {
  local terminal_width=$(tput cols)
  pkg.gum style \
    --foreground "#F02" --border-foreground "#F02" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}

pkg.gum.success_box() {
  local terminal_width=$(tput cols)
  pkg.gum style \
    --foreground "#0F0" --border-foreground "#0F0" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}
