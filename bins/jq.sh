#!/usr/bin/env bash

if [[ $1 = "--help" ]]; then
  cat <<EOF

USAGE: jq_solos <...jq arguments...>

DESCRIPTION:

jq_solos is a proxy for jq, that ensures our custom jq modules are loaded and that we \
don't need to specify the path to them.

WARNINGS: 

When using \`jq_solos\`, do not supply your own -L option.

EOF
  exit 0
fi

__bins_jq__fn__main() {
  local jq_bin_path="$(which jq)"
  if [ -z "${jq_bin_path}" ]; then
    echo "jq_solos is a proxy for jq, but jq is not installed. Please install jq first." >&2
    exit 1
  fi
  local modules="$(find /root/.solos/src/jq -type f -name "*.jq" -exec basename {} \; | sed 's/,$//' | sed 's/.jq//g')"
  local include_statements=""
  for module in ${modules}; do
    include_statements="${include_statements}include \"${module}\"; "
  done
  local options=()
  local positional=()
  for arg in "$@"; do
    if [[ "${arg}" == '-L'* ]]; then
      echo "The -L option is fixed in jq_solos. Use jq instead." >&2
      exit 1
    elif [[ "${arg}" == -* ]]; then
      options+=("${arg}")
    else
      positional+=("${arg}")
    fi
  done
  "${jq_bin_path}" "${options[@]}" -L/root/.solos/src/jq "${include_statements[*]} ${positional[@]}"
}

__bins_jq__fn__main "$@"
