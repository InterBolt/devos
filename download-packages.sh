#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(dirname "${BASH_SOURCE[0]}")"

# Mac Intel
# https://github.com/charmbracelet/gum/releases/download/v0.13.0/gum_0.13.0_Darwin_x86_64.tar.gz
# Mac M1
# https://github.com/charmbracelet/gum/releases/download/v0.13.0/gum_0.13.0_Darwin_arm64.tar.gz
# Servers
# https://github.com/charmbracelet/gum/releases/download/v0.13.0/gum_0.13.0_Linux_arm.tar.gz
