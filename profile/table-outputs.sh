#!/usr/bin/env bash

__table_outputs__fn__extract_help_description() {
  local help_output=$(cat)
  if [[ -z ${help_output} ]]; then
    echo "Unexpected error: empty help output." >&2
    return 1
  fi
  local description_line_number=$(echo "${help_output}" | grep -n "^DESCRIPTION:" | cut -d: -f1)
  if [[ -z ${description_line_number} ]]; then
    echo "Unexpected error: invalid help output format. Could not find DESCRIPTION: line." >&2
    return 1
  fi
  local first_description_line=$((description_line_number + 2))
  if [[ -z $(echo "${help_output}" | sed -n "${first_description_line}p") ]]; then
    echo "Unexpected error: invalid help output format. No text was found on the second line after DESCRIPTION:" >&2
    return 1
  fi
  echo "${help_output}" | cut -d$'\n' -f"${first_description_line}"
}

__table_outputs__fn__help() {
  local newline=$'\n'
  local output=""
  local idx=0
  for command_name in "$@"; do
    local command_description="$("${command_name}" --help | __table_outputs__fn__extract_help_description)"
    if [[ ${idx} -eq 0 ]]; then
      output+="${command_name}^${command_description}"
    else
      output+="${newline}${command_name}^${command_description}"
    fi
    idx=$((idx + 1))
  done
  output=$(echo "${output}" | column -t -N COMMANDS,DESCRIPTIONS -s '^' -o '|')
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
  echo "${lines}" | sed 's/|/  /g'
  unset IFS
}

__table_outputs__fn__format() {
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
  output=$(echo "${output}" | column -t -N "${headers}" -s '^' -o '|')
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
  echo "${lines}" | sed 's/|/  /g'
  unset IFS
}
