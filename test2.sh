#!/bin/bash

lib.line_to_args() {
  local lines="${1}"
  local index="${2}"
  if [[ ${index} -eq 0 ]]; then
    echo "${lines}" | head -n 1 | xargs
  else
    echo "${lines}" | head -n "$((index + 1))" | tail -n 1 | xargs
  fi
}

lib.line_to_args_modded() {
  local input_text="${1:-"$(cat)"}"
  local index="${2:-"0"}"
  if [[ -z "${input_text}" ]]; then
    echo ""
    return 0
  fi
  local lines=()
  while IFS= read -r line; do
    lines+=("${line}")
  done <<<"${input_text}"
  local print_line="${lines[${index}]}"
  echo "${print_line}" | xargs
}

val="$(
  cat <<EOF
architect https://raw.githubusercontent.com/InterBolt/solos/main/dev/mocks/remote-plugin-downloads/architect.sh codesniff https://raw.githubusercontent.com/InterBolt/solos/main/dev/mocks/remote-plugin-downloads/codesniff.sh todos https://raw.githubusercontent.com/InterBolt/solos/main/dev/mocks/remote-plugin-downloads/todos.sh
EOF
)"

first_old=($(lib.line_to_args "${val}" "0"))
second_old=($(lib.line_to_args "${val}" "1"))

first_new=($(lib.line_to_args_modded "${val}" "0"))
second_new=($(lib.line_to_args_modded "${val}" "1"))

echo "First old: ${first_old[@]}"
echo "Second old: ${second_old[@]}"
echo "First new: ${first_new[@]}"
echo "Second new: ${second_new[@]}"
