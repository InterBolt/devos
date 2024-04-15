#!/usr/bin/env bash

get_run_type() {
  if [[ -z $BASH_VERSION ]]; then
    echo "unsupported shell detected. try again with Bash." >&2
    exit 1
  fi
  if command -v docker >/dev/null 2>&1; then
    echo "docker"
    exit 0
  fi
  if ! command -v lsb_release >/dev/null 2>&1; then
    echo "Error: either install docker or ensure you're using a stable version of debian." >&2
    exit 1
  elif [[ $(lsb_release -i -s 2>/dev/null) != "Debian" ]]; then
    echo "Error: either install docker or ensure you're using a stable version of debian." >&2
    exit 1
  fi
  echo "direct"
}

main() {
  local config_dir="${HOME}/.solos"
  if [[ -f ${config_dir} ]]; then
    echo "Error: a filed called .solos was detected in your home directory." >&2
    echo "SolOS cannot create a dir named .solos in your home directory." >&2
    exit 1
  fi
  mkdir -p "${config_dir}"
  local run_type=$(get_run_type)
  if [[ $run_type = "docker" ]]; then
    docker run --rm -it -v "${HOME}/.solos:/root/.solos" solos:latest /root/.solos/bin/solos.sh "$@"
  else
    "${HOME}/.solos/bin/solos.sh" "$@"
  fi
}

main "$@"
