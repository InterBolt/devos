#!/usr/bin/env sh

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

  tmp_dir="$(mktemp -d 2>/dev/null)"
  git clone "https://github.com/InterBolt/solos.git" "${tmp_dir}" >/dev/null
  find "${tmp_dir}" -type f -exec chmod +x {} \;
  bash "${tmp_dir}/host/installer.sh" --dev
}

main
