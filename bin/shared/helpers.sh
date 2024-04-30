#!/usr/bin/env bash

# The parsing logic we use for the main CLI commands will need to handle more
# types of use cases and provide stronger UX. As a result, it prone to grow in
# complexity. This flag parse OTOH is used by devs only and doesn't need to be pretty.
helpers.simple_flag_parser() {
  vPREV_RETURN=()
  local flag_names=()
  while [[ $# -gt 0 ]] && [[ $1 != "ARGS:" ]]; do
    flag_names+=("$1")
    shift
  done
  if [[ $1 != "ARGS:" ]]; then
    echo "Unexpected error: no 'ARGS:' separator found." >&2
    exit 1
  fi
  shift
  local flag_values=()
  for flag_name in "${flag_names[@]}"; do
    for cli_arg in "$@"; do
      if [[ ${cli_arg} = "${flag_name}" ]] || [[ ${cli_arg} = "${flag_name}="* ]]; then
        if [[ ${cli_arg} = *'='* ]]; then
          flag_values+=("${cli_arg#*=}")
        else
          flag_values+=("true")
        fi
        set -- "${@/''"${cli_arg}"''/}"
      fi
    done
  done

  # Now remove the flags we already parsed.
  local nonempty_cli_args=()
  for cli_arg in "$@"; do
    if [ -n "${cli_arg}" ]; then
      nonempty_cli_args+=("${cli_arg}")
    fi
  done
  set -- "${nonempty_cli_args[@]}" || exit 1
  vPREV_NEXT_ARGS=("$@")
  vPREV_RETURN=("${flag_values[@]}")
}

helpers.run_anything() {
  local home_path="$1"
  shift
  if [[ $1 = "-" ]]; then
    if [[ -z ${home_path} ]]; then
      echo "No home path found at: ${home_path}" >&2
      exit 1
    fi
    local filepath="${2/${home_path}/\/root}"
    cd .. || exit 1
    "${filepath}" "${@:3}"
    exit 0
  fi
}
