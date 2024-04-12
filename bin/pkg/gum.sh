#!/usr/bin/env bash
# shellcheck disable=SC2115

set -o errexit
set -o pipefail
set -o errtrace

cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..
LIB_ENTRYPOINT_DIR="$(pwd)"

GUM_VERSION="0.13.0"
GUM_RELEASES_URL="https://github.com/charmbracelet/gum/releases/download"

pkg.gum._get_release_download_url() {
  local release=""
  if [[ $(uname) == 'Darwin' ]]; then
    if [[ $(uname -m) == 'arm64' ]]; then
      release="${GUM_RELEASES_URL}/v${GUM_VERSION}/gum_${GUM_VERSION}_Darwin_arm64.tar.gz"
    else
      release="${GUM_RELEASES_URL}/v${GUM_VERSION}/gum_${GUM_VERSION}_Darwin_x86_64.tar.gz"
    fi
  else
    if [[ $(uname -m) == 'arm64' ]]; then
      release="${GUM_RELEASES_URL}/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_arm64.tar.gz"
    else
      release="${GUM_RELEASES_URL}/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_x86_64.tar.gz"
    fi
  fi
  echo "${release}"
}

pkg.gum.install() {
  local release="$(pkg.gum._get_release_download_url)"
  local release_download_dirname="$(basename "${release}" | sed 's/.tar.gz//')"
  local location_dir="${LIB_ENTRYPOINT_DIR}/pkg/.binaries/${release_download_dirname}"
  mkdir -p "${location_dir}"
  if [ ! -f "${location_dir}/gum" ]; then
    curl -L --silent --show-error "${release}" | tar -xz -C "${location_dir}"
  fi
  echo "${location_dir}/gum"
}

pkg.gum() {
  local executable_path="$(pkg.gum.install)"
  if [ -f "${executable_path}" ]; then
    "$executable_path" "$@"
  else
    echo "failed to install gum" >&2
    exit 1
  fi
}

LIB_GUM_INSTALL_PATH="$(pkg.gum.install)"
if [ ! -f "${LIB_GUM_INSTALL_PATH}" ]; then
  echo "failed to install gum" >&2
  exit 1
fi
