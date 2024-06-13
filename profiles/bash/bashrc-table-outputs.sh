#!/usr/bin/env bash

. "${HOME}/.solos/src/shared/lib.sh" || exit 1

# Fixes aligment and word wrapping issues with the built-in table command.
bashrc_table_outputs.format() {
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
  local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
  local output="$(echo "${lines}" | sed 's/|/  /g' | sed '2s/^/'"${full_line}"'\n/')"
  echo "${output}"
  unset IFS
}
