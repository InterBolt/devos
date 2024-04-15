#!/usr/bin/env bash
# shellcheck disable=SC2115

LIB_ENTRY_DIR="${PWD}"
LIB_PKG_DIR="${LIB_ENTRY_DIR}/pkg"
LIB_RELEASES_DIRNAME=".installs"
LIB_GUM_VERSION="0.13.0"
LIB_GUM_RELEASES_URL="https://github.com/charmbracelet/gum/releases/download"

if [[ ! -d ${LIB_PKG_DIR} ]]; then
  echo "failed to find bin/pkg directory. cannot install gum" >&2
  exit 1
fi

pkg.gum._get_release_download_url() {
  local release=""
  if [[ $(uname) = 'Darwin' ]]; then
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${LIB_GUM_RELEASES_URL}/v${LIB_GUM_VERSION}/gum_${LIB_GUM_VERSION}_Darwin_arm64.tar.gz"
    else
      release="${LIB_GUM_RELEASES_URL}/v${LIB_GUM_VERSION}/gum_${LIB_GUM_VERSION}_Darwin_x86_64.tar.gz"
    fi
  else
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${LIB_GUM_RELEASES_URL}/v${LIB_GUM_VERSION}/gum_${LIB_GUM_VERSION}_Linux_arm64.tar.gz"
    else
      release="${LIB_GUM_RELEASES_URL}/v${LIB_GUM_VERSION}/gum_${LIB_GUM_VERSION}_Linux_x86_64.tar.gz"
    fi
  fi
  echo "${release}"
}

pkg.gum.install() {
  local release="$(pkg.gum._get_release_download_url)"
  local release_download_dirname="$(basename "${release}" | sed 's/.tar.gz//')"
  local location_dir="${LIB_PKG_DIR}/${LIB_RELEASES_DIRNAME}/${release_download_dirname}"
  mkdir -p "${location_dir}"
  if [[ ! -f ${location_dir}/gum ]]; then
    curl -L --silent --show-error "${release}" | tar -xz -C "${location_dir}"
  fi
  echo "${location_dir}/gum"
}

pkg.gum() {
  local executable_path="$(pkg.gum.install)"
  if [[ -f ${executable_path} ]]; then
    "$executable_path" "$@"
  else
    echo "failed to install gum" >&2
    exit 1
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

pkg.gum.info_box() {
  local terminal_width=$(tput cols)
  pkg.gum style \
    --foreground "#3B78FF" --border-foreground "#3B78FF" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}

pkg.gum.debug_box() {
  local terminal_width=$(tput cols)
  pkg.gum style \
    --foreground "#A0A" --border-foreground "#A0A" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}

pkg.gum.logs_box() {
  local terminal_width="$(tput cols)"
  pkg.gum style \
    --foreground "#FFF" --border-foreground "#FFF" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}

pkg.gum.warning_box() {
  local terminal_width=$(tput cols)
  pkg.gum style \
    --foreground "#FA0" --border-foreground "#FA0" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}
