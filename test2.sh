#!/bin/bash
lib.table_format() {
  local headers="$1"
  shift
  local newline=$'\n'
  local output=""
  local idx=0
  local idx_rows=0
  local curr_key=""
  local curr_description=""
  for key_or_description in "$@"; do
    if [[ $((idx % 2)) -eq 0 ]]; then
      curr_key="${key_or_description}"
      curr_description=""
    else
      curr_description="${key_or_description}"
    fi
    if [[ -n ${curr_description} ]]; then
      if [[ ${idx_rows} -eq 0 ]]; then
        output+="${curr_key}^${curr_description}"
      else
        output+="${newline}${curr_key}^${curr_description}"
      fi
      idx_rows=$((idx_rows + 1))
    fi
    idx=$((idx + 1))
  done
  output=$(echo "${output}" | column -t "${headers}" -s '^' -o '|')
  IFS=$'\n'
  local lines=""
  for line in ${output}; do
    local c1="$(echo "${line}" | cut -d '|' -f1)"
    local c2="$(echo "${line}" | cut -d '|' -f2 | fold -s -w 80)"
    idx=0
    for description_line in ${c2}; do
      if [[ ${idx} -eq 0 ]]; then
        line="${c1}|${description_line}"
      else
        line+="${IFS}$(printf '%*s' "${#c1}" '')  ${description_line}"
      fi
      idx=$((idx + 1))
    done
    lines+="${line}${IFS}"
  done
  local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
  local output="$(echo "${lines}" | sed 's/|/  /g' | sed '2s/^/'"${full_line}"'\n/')"
  echo "${output}"
  unset IFS
}

lib.extract_usage_description() {
  local help_output=$(cat)
  if [[ -z ${help_output} ]]; then
    echo "[FAILED TO EXTRACT] - no help output provided"
    return 1
  fi
  local description_header_line_number=$(echo "${help_output}" | grep -n "^DESCRIPTION:" | cut -d: -f1)
  if [[ -z ${description_header_line_number} ]]; then
    echo "[FAILED TO EXTRACT] - no description line found in help output"
    return 1
  fi
  local description_text_line_number=$((description_header_line_number + 2))
  local description_text="$(echo "${help_output}" | sed -n "${description_text_line_number}p")"
  if [[ -z ${description_text} ]]; then
    echo "[FAILED TO EXTRACT] - no description found in help output"
    return 1
  fi
  echo "${description_text}"
}

placeholder() {
  cat <<EOF
USAGE: placeholder

DESCRIPTION:

This for testing does it working????

No maybe idk please work \
ok.

COMMANDS:

add <name>      - Add an app to the project.

EOF
}

lib.table_format \
  "SHELL_COMMAND,DESCRIPTION" \
  '-' "Runs its arguments as a command. Avoids pre/post exec functions and output tracking." \
  info "Print info about this shell." \
  app "$(placeholder | lib.extract_usage_description)" \
  plugins "$(placeholder | lib.extract_usage_description)" \
  daemon "$(placeholder | lib.extract_usage_description)" \
  track "$(placeholder | lib.extract_usage_description)" \
  preexec "$(placeholder | lib.extract_usage_description)" \
  postexec "$(placeholder | lib.extract_usage_description)" \
  reload "$(placeholder | lib.extract_usage_description)" \
  panics "$(placeholder | lib.extract_usage_description)"
