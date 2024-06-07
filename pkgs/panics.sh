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
  local timestamp="$(date +"%Y-%m-%dT%H:%M:%S")"
  local panicfile="${panics__dir}/${key}"
  mkdir -p "${panics__dir}"
  cat <<EOF >"${panicfile}"
MESSAGE:

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
panics_print_all() {
  for panicfile in "${panics__dir}"/*; do
    cat "${panicfile}"
  done
}
