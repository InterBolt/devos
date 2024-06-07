#!/usr/bin/env bash

# "Panics" are just files that follow a naming convention and structure:
# - They are named `<key>-<timestamp>`
# - They contain text about some problem that occurred internally in the format:
#   ```
#   <MESSAGE>
#
#   TIME: <TIMESTAMP>
#   SEVERITY: <SEVERITY>
#  ```
# When a "panic" is added, we supply a key which is helpful if the same panic is added multiple times.
# We can delete all panics with a common key by providing the key as an arg to panics_remove.
# But we can also simply supply a string that, if found, tells panic_remove to delete those that match.
# "panics_clear" simply wipes all panics.
# IMPORTANT: panics must have zero dependencies on other pkgs and scripts because they are used in the event of a catastrophic failure
# and should minimize the chance of panics...panicking themselves?
# This means we will use echo's rather than log_* functions and that's fine.
panics__dir="${HOME}/.solos/data/panics"

panics.count() {
  local filecount="$(ls -a1 "${panics__dir}" | wc -l)"
  # Don't count the "." and ".." directories.
  filecount="$((filecount - 2))"
  echo "${filecount}"
}

# PUBLIC FUNCTIONS

panics_add() {
  # msg is stdin since we expect to use heredocs for rich multiline explanations.
  local msg="$(cat)"
  local key="${1}"
  if [[ -z ${key} ]]; then
    echo "Failed to panic: no key supplied" >&2
    return 1
  fi
  local severity="${2:-"HIGH"}"
  local nanoseconds="$(date +%s%N)"
  local timestamp="$(date +"%Y-%m-%dT%H:%M:%S")"
  local panicfile="${panics__dir}/${nanoseconds}.${key}"
  mkdir -p "${panics__dir}"
  cat <<EOF >"${panicfile}"
${msg}

TIME: ${timestamp}
SEVERITY: ${severity}
EOF
  if ! tail -n 1 "${panicfile}" | grep -q "^SEVERITY"; then
    echo "Failed to panic: ${panicfile} is malformed" >&2
    return 1
  fi
  return 0
}
panics_clear() {
  if [[ ! -d "${panics__dir}" ]]; then
    return 1
  fi
  local panic_count="$(panics.count)"
  if [[ ${panic_count} -eq 0 ]]; then
    return 1
  fi
  rm -rf "${panics__dir}"
  mkdir -p "${panics__dir}"
  return 0
}
panics_remove() {
  local key_or_match_pattern="${1}"
  local panic_count="$(panics.count)"
  if [[ ${panic_count} -eq 0 ]]; then
    return 1
  fi
  # TODO: hack because it works with single brackets not double, despite double being the
  # TODO[c]: pattern I wanted to stick with for consistency.
  if [ -f "${panics__dir}/"*".${key_or_match_pattern}" ]; then
    rm -f "${panics__dir}/"*".${key_or_match_pattern}"
  else
    for panicfile in "${panics__dir}"/*; do
      if grep -q "${key_or_match_pattern}" "${panicfile}"; then
        rm -f "${panicfile}"
      fi
    done
  fi
  local final_panic_count="$(panics.count)"
  if [[ ${panic_count} -eq ${final_panic_count} ]]; then
    return 1
  fi
  return 0
}
# Gets all the latest panic files. So if there are two files for a given key, it only gets the latest.
panics_print_latest() {
  local key_or_match_pattern="${1}"
  local printset=()
  for panicfile in "${panics__dir}/"*; do
    if [[ ! -f ${panicfile} ]]; then
      continue
    fi
    if [[ -z ${key_or_match_pattern} ]]; then
      printset+=("${panicfile}")
      continue
    fi
    if [[ "$(basename "${panicfile}")" = *".${key_or_match_pattern}" ]]; then
      printset+=("${panicfile}")
    fi
  done
  if [[ ${#printset[@]} -gt 0 ]]; then
    local i=0
    for printfile in "${printset[@]}"; do
      if [[ ${i} -gt 0 ]]; then
        echo ""
      fi
      if ! cat "${printfile}"; then
        return 2
      fi
      i=$((i + 1))
    done
    return 0
  fi
  for panicfile in "${panics__dir}"/*; do
    if [[ ! -f ${panicfile} ]]; then
      continue
    fi
    if grep -q "${key_or_match_pattern}" "${panicfile}"; then
      printset+=("${panicfile}")
    fi
  done
  i=0
  for printfile in "${printset[@]}"; do
    if [[ ${i} -gt 0 ]]; then
      echo ""
    fi
    if ! cat "${printfile}"; then
      return 2
    fi
    i=$((i + 1))
  done
  if [[ ${#printset[@]} -eq 0 ]]; then
    return 1
  fi
  return 0
}
panics_print_all() {
  local keys=()
  for panicfile in "${panics__dir}"/*; do
    local key="$(basename "${panicfile}" | cut -d "." -f2)"
    if ! echo "${keys[@]}" | grep -q "${key}"; then
      keys+=("${key}")
    fi
  done
  for key in "${keys[@]}"; do
    if ! panics_print_latest "${key}"; then
      return 1
    fi
  done
}
