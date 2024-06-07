#!/usr/bin/env bash

# This is the copied code that we must test here:
# ```
# #!/usr/bin/env bash
# # "Panics" are just files that follow a naming convention and structure:
# # - They are named `<key>-<timestamp>`
# # - They contain text about some problem that occurred internally in the format:
# #   ```
# #   <MESSAGE>
# #
# #   TIME: <TIMESTAMP>
# #   SEVERITY: <SEVERITY>
# #  ```
# # When a "panic" is added, we supply a key which is helpful if the same panic is added multiple times.
# # We can delete all panics with a common key by providing the key as an arg to panics_remove.
# # But we can also simply supply a string that, if found, tells panic_remove to delete those that match.
# # "panics_clear" simply wipes all panics.
# # IMPORTANT: panics must have zero dependencies on other pkgs and scripts because they are used in the event of a catastrophic failure
# # and should minimize the chance of panics...panicking themselves?
# # This means we will use echo's rather than log_* functions and that's fine.

# panics__dir="${HOME}/.solos/data/panics"

# # PUBLIC FUNCTIONS

# panics_add() {
#   # msg is stdin since we expect to use heredocs for rich multiline explanations.
#   local msg="$(cat)"
#   local key="${1}"
#   if [[ -z ${key} ]]; then
#     echo "Failed to panic: no key supplied" >&2
#     echo "false"
#     return 1
#   fi
#   local severity="${2:-"HIGH"}"
#   local nanoseconds="$(date +%s%N)"
#   local timestamp="$(date +"%Y-%m-%dT%H:%M:%S")"
#   local panicfile="${panics__dir}/${key}-${nanoseconds}"
#   mkdir -p "${panics__dir}"
#   cat <<EOF >"${panicfile}"
# ${msg}

# TIME: ${timestamp}
# SEVERITY: ${severity}
# EOF
#   if ! tail -n 1 "${panicfile}" | grep -q "^SEVERITY"; then
#     echo "Failed to panic: ${panicfile} is malformed" >&2
#     echo "false"
#     return 1
#   fi
#   echo "true"
#   return 0
# }
# panics_clear() {
#   rm -rf "${panics__dir}"
#   mkdir -p "${panics__dir}"
# }
# panics_remove() {
#   local key_or_match_pattern="${1}"
#   local panic_filecount="$(ls -a1 "${panics__dir}" | wc -l)"
#   # Don't count the "." and ".." directories.
#   panic_filecount="$((panic_filecount - 2))"
#   if [[ -f "${panics__dir}/${key_or_match_pattern}-"* ]]; then
#     rm -f "${panics__dir}/${key_or_match_pattern}-"*
#   else
#     for panicfile in "${panics__dir}"/*; do
#       if grep -q "${key_or_match_pattern}" "${panicfile}"; then
#         rm -f "${panicfile}"
#       fi
#     done
#   fi
#   local final_panic_filecount="$(ls -a1 "${panics__dir}" | wc -l)"
#   final_panic_filecount="$((final_panic_filecount - 2))"
#   if [[ ${panic_filecount} -eq ${final_panic_filecount} ]]; then
#     echo "false"
#     return 1
#   fi
#   echo "true"
#   return 0
# }
# # Gets all the latest panic files. So if there are two files for a given key, it only gets the latest.
# panics_print_latest() {
#   local key_or_match_pattern="${1}"
#   local latest=()
#   for panicfile in "${panics__dir}/${key_or_match_pattern}-"*; do
#     latest+=("${panicfile}")
#   done
#   if [[ ${#latest[@]} -gt 0 ]]; then
#     local i=0
#     for panicfile in "${latest[@]}"; do
#       if [[ ${i} -gt 0 ]]; then
#         echo ""
#       fi
#       cat "${panicfile}"
#       i=$((i + 1))
#     done
#     return 0
#   fi
#   for panicfile in "${panics__dir}"/*; do
#     if grep -q "${key_or_match_pattern}" "${panicfile}"; then
#       latest+=("${panicfile}")
#     fi
#   done
#   i=0
#   for panicfile in "${latest[@]}"; do
#     if [[ ${i} -gt 0 ]]; then
#       echo ""
#     fi
#     cat "${panicfile}"
#     i=$((i + 1))
#   done
#   return 0
# }
# panics_print_all() {
#   local keys=()
#   for panicfile in "${panics__dir}"/*; do
#     local key="$(basename "${panicfile}" | cut -d "-" -f 1)"
#     if ! echo "${keys[@]}" | grep -q "${key}"; then
#       keys+=("${key}")
#     fi
#   done
#   for key in "${keys[@]}"; do
#     panics_print_latest "${key}"
#   done
# }
# ```

. "${HOME}/.solos/src/pkgs/panics.sh"

test_panic() {
  local full_line="$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)"
  echo "${full_line}"
  panics_clear
  echo "${full_line}"
  panics_add "test-key-jiberarish-one" <<EOF
alksdjfaiusdfkahsdf jas dfljkashdf klasjhf klasdf
EOF
  echo "EXPECTING RETURN CODE 0 FOR panics_add: $?"
  echo "${full_line}"
  panics_add <<EOF
alksdjfaiusdfkahsdf jas dfljkashdf klasjhf klasdf
EOF
  echo "EXPECTING RETURN CODE 1 FOR panics_add: $?"
  echo "${full_line}"
  # Test the panics_add function
  panics_add "test-key-one" "LOW" <<EOF
This is a test panic message ONE.
EOF
  echo "${full_line}"
  panics_add "test-key-two" "MEDIUM" <<EOF
This is a test panic message TWO.
EOF
  echo "${full_line}"
  panics_add "test-key-three" "HIGH" <<EOF
This is a test panic message THREE.
SPECIAL_STRING that should allow us to print this message simply by knowing it.
EOF
  echo "${full_line}"
  panics_print_all
  echo "EXPECTING RETURN CODE 0 FOR panics_print_all: $?"
  echo "${full_line}"
  panics_remove "test-key-one"
  echo "EXPECTING RETURN_CODE 0 FOR panics_remove: $?"
  echo "${full_line}"
  panics_print_latest "test-key-one"
  echo "EXPECTING RETURN_CODE 1 FOR panics_print_latest: $?"
  echo "${full_line}"
  panics_print_latest "test-key-two"
  echo "EXPECTING RETURN CODE 0 FOR panics_print_latest: $?"
  echo "${full_line}"
  panics_print_all
  echo "EXPECTING RETURN CODE 0 FOR panics_print_all: $?"
  echo "${full_line}"
  panics_print_latest "SPECIAL_STRING"
  echo "EXPECTING RETURN CODE 0 FOR panics_print_latest: $?"
  echo "${full_line}"
  panics_remove "test-key-three"
  echo "EXPECTING RETURN_CODE 0 FOR panics_remove: $?"
  echo "${full_line}"
  panics_remove "test-key-three"
  echo "EXPECTING RETURN_CODE 1 FOR panics_remove: $?"
  echo "${full_line}"
  panics_print_latest "SPECIAL_STRING"
  echo "EXPECTING RETURN CODE 1 FOR panics_print_latest: $?"
  echo "${full_line}"
}

test_panic
