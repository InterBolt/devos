#!/usr/bin/env bash

shopt -s extdebug

# preexec() {
#   local return_code=127
#   {
#     local stdout_file="${HOME}/.solos/rag/.stdout"
#     local stderr_file="${HOME}/.solos/rag/.stderr"
#     local cmd_file="${HOME}/.solos/rag/.cmd"
#     local exit_code_file="${HOME}/.solos/rag/.exit_code"
#     local rag_stdout_file="${HOME}/.solos/rag/.stdout_rag"
#     local rag_stderr_file="${HOME}/.solos/rag/.stderr_rag"
#     rm -f \
#       "${stdout_file}" \
#       "${stderr_file}" \
#       "${cmd_file}" \
#       "${rag_stdout_file}" \
#       "${rag_stderr_file}"
#     echo "${cmd}" >"${cmd_file}"
#     exec \
#       > >(tee >(grep "^\[RAG\]" >>"${rag_stdout_file}") "${stdout_file}") \
#       2> >(tee >(grep "^\[RAG\]" >>"${rag_stderr_file}") "${stderr_file}" >&2)
#     eval "${1}"
#     echo "${?}" >"${exit_code_file}"
#   } | cat
#   # rag --capture
#   return ${return_code}
# }

# preexec_trap() {
#   if [[ "${BASH_COMMAND}" = "__bs__var=t" ]]; then
#     return 0
#   fi
#   if [[ -n "${__bs__var+set}" ]]; then
#     unset __bs__var
#     local full_cmd="$(history 1 | xargs | cut -d' ' -f2-)"
#     trap - DEBUG
#     preexec ''"${full_cmd}"''
#     trap 'preexec_trap' DEBUG
#   fi
#   return 1
# }

# PROMPT_COMMAND='__bs__var=t'
# trap 'preexec_trap' DEBUG

# sleep 4

# echo "HELLO"

# sleep 2

# trap_add() {
#   local fn="$1"
#   local signal="$2"
#   if ! declare -f "${fn}" >/dev/null; then
#     echo "Unexpected error: ${fn} is not a function."
#     return 1
#   fi
#   if ! kill -l "${signal}" >/dev/null 2>&1; then
#     echo "Unexpected error: ${signal} is not a valid signal."
#     return 1
#   fi
#   if [[ -z "$(trap -p "${signal}")" ]]; then
#     trap ''"${fn}"';' "${signal}"
#     return 0
#   fi
#   local prev_trap="$(trap -p "${signal}" | cut -d' ' -f3- | rev | cut -d' ' -f2- | rev)"
#   prev_trap="${prev_trap//\'/}"
#   prev_trap="$(echo "${prev_trap}" | xargs)"
#   trap ''"${fn}"'; '"${prev_trap}"'' "${signal}"
# }

# trap_remove() {
#   local fn="$1"
#   local signal="$2"
#   if ! declare -f "${fn}" >/dev/null; then
#     echo "Unexpected error: ${fn} is not a function."
#     return 1
#   fi
#   if ! kill -l "${signal}" >/dev/null 2>&1; then
#     echo "Unexpected error: ${signal} is not a valid signal."
#     return 1
#   fi
#   if [[ -z "$(trap -p "${signal}")" ]]; then
#     return 0
#   fi
#   local prev_trap="$(trap -p "${signal}" | cut -d' ' -f3- | rev | cut -d' ' -f2- | rev)"
#   local next_trap="${prev_trap//${fn};/}"
#   next_trap="${next_trap//${fn}/}"
#   if [[ -z "${next_trap}" ]]; then
#     trap - "${signal}"
#   else
#     trap ''"$(echo "${next_trap}" | xargs)"'' "${signal}"
#   fi
# }

# initial_trap() {
#   echo "INITIAL" >&2
# }
# random_trap_a() {
#   echo "RANDOM A" >&2
# }
# random_trap_b() {
#   echo "RANDOM B" >&2
# }
# random_trap_c() {
#   echo "RANDOM C" >&2
# }

# trap 'initial_trap' DEBUG

# trap_add 'random_trap_a' DEBUG
# trap_add 'random_trap_b' DEBUG
# trap_remove 'random_trap_a' DEBUG
# trap_add 'random_trap_c' DEBUG

# echo "first trapped cmd"
# echo "second trapped cmd"

# trap_add 'random_trap_a' DEBUG
# trap_remove 'random_trap_c' DEBUG

# echo "third trapped cmd"
# echo "fourth trapped cmd"

# some_func() {
#   echo "some_func"
# }

# trap 'echo "hi"' DEBUG

# prev_trap="$(trap -p DEBUG | cut -d' ' -f3- | rev | cut -d' ' -f2- | rev | xargs)"

# echo "prev_trap - ${prev_trap}"

# trap "some_func; ${prev_trap}" DEBUG

# prev_trap="$(trap -p DEBUG | cut -d' ' -f3- | rev | cut -d' ' -f2- | rev | xargs)"

# echo "prev_trap - ${prev_trap}"

# printf "\x00\x01\x02\x03\x04" >/root/.solos/binary_file.bin

# preexec() {
#   return "${1}"
# }

# some_fn() {
#   local prompt="${1}"
#   if [[ ${prompt} = *"|"* ]]; then
#     echo "pipe"
#   else
#     echo "no pipe"
#   fi
# }

# some_fn "hello"
# some_fn "- hello"
# some_fn "- hello | alskdjf"

# preexec_list() {
#   echo "${user_preexecs[@]}"
# }

# preexec_add() {
#   local fn="${1}"
#   if [[ -z ${fn} ]]; then
#     echo "preexec: missing function name" >&2
#     return 1
#   fi
#   if ! declare -f "${fn}" >/dev/null; then
#     echo "preexec: function '${fn}' not found" >&2
#     return 1
#   fi
#   if [[ " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
#     echo "preexec: function '${fn}' already exists in user_preexecs" >&2
#     return 1
#   fi
#   user_preexecs+=("${fn}")
# }

# preexec_remove() {
#   local fn="${1}"
#   if [[ ! " ${user_preexecs[@]} " =~ " ${fn} " ]]; then
#     echo "Invalid usage: preexec: function '${fn}' not found in user_preexecs" >&2
#     return 1
#   fi
#   user_preexecs=("${user_preexecs[@]/${fn}/}")
# }

# some_fn() {
#   echo "some_fn"
# }

# another_fn() {
#   echo "another_fn"
# }
# set -x
# # test various cases
# user_preexecs=()
# sleep .2
# preexec_list
# sleep .2
# preexec_add 'some_fn'
# sleep .2
# preexec_list
# sleep .2
# preexec_add 'another_fn'
# sleep .2
# preexec_list
# sleep .2
# preexec_remove 'some_fn'
# sleep .2
# preexec_list
# sleep .2
# preexec_remove 'another_fn'
# sleep .2
# preexec_list
# sleep .2
# preexec_add 'some_fn'
# sleep .2
# preexec_list
# sleep .2
# preexec_add 'another_fn'
# sleep .2
# preexec_list
# sleep .2
# preexec_remove 'some_fn'
# sleep .2
# preexec_add 'another_fn'

set -x

nonexistentarr=('HEY_MAN')

if [[ -z "${nonexistentarr:-}" ]]; then
  preexecs=()
else
  preexecs=("${nonexistentarr[@]}")
fi

for fn_name in "${preexecs[@]}"; do
  echo "fn_name - ${fn_name}"
done
