#!/usr/bin/env bash

# This script simply verifies the existence of dependencies and downloads/runs the the installer script.
# Always execute all logic in a main function to prevent partial execution of the script.
# Important: must be posix compliant up to the `curl url | bash` line.

get_install_script_url() {
  date_seconds=$(date +%s)
  echo "https://raw.githubusercontent.com/InterBolt/solos/main/host/installer.sh?token=${date_seconds}"
}

main() {
  if ! command -v bash >/dev/null 2>&1; then
    echo "Bash is required to install SolOS on this system." >&2
    exit 1
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to install SolOS on this system." >&2
    exit 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "Git is required to install SolOS on this system." >&2
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "Curl is required to install SolOS on this system." >&2
    exit 1
  fi

  installer_script_url="$(get_install_script_url)"
  . <(curl -s "${installer_script_url}")
}

main
