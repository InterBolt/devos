#!/usr/bin/env bash

# A portable bash library for use in and out of our container.

# RULES:
# 1. Take great care using sed, grep, and any obscure substitutions. These have GNU/BSD differences.
# 2. Never use arrays. Prefer space or newline separated strings.
# 3. Always use `local` to avoid polluting the global scope.
# 4. Always use `echo` for output. Avoid `printf` for portability.
# 5. Always use `cat` for reading files. Avoid `head`, `tail`, and `sed` for portability.

# Obsessively validate all commands we might use and verify the bash version.
__internal__lib__verify() {
  local required_cmds=(
    "echo"
    "head"
    "xargs"
    "cat"
    "mkdir"
    "ls"
    "read"
    "rm"
    "wc"
  )
  if [[ ${BASH_VERSINFO[0]} -lt 3 ]]; then
    echo "Unexpected error: lib functions require a bash version >= 3" >&2
    exit 1
  fi
  for cmd in "${required_cmds[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "Unexpected error: missing required command: ${cmd}" >&2
      exit 1
    fi
  done
}
__internal__lib__verify

lib__data_dir="${HOME}/.solos/data"
lib__panics_dir="${lib__data_dir}/panics"
lib__store_dir="${lib__data_dir}/store"

lib.data_dir_path() {
  echo "${lib__data_dir}"
}
export -f lib.data_dir_path

lib.panic_dir_path() {
  echo "${lib__panics_dir}"
}
export -f lib.panic_dir_path

lib.last_docker_build_hash_path() {
  echo "${lib__store_dir}/last_docker_build_hash" | xargs
}
export -f lib.last_docker_build_hash_path

lib.checked_out_project() {
  local checked_out_project="$(cat "${lib__store_dir}/checked_out_project" 2>/dev/null || echo "" | xargs)"
  if [[ -z "${checked_out_project}" ]]; then
    return 1
  fi
  echo "${checked_out_project}"
}
export -f lib.checked_out_project

lib.home_dir_path() {
  local home_dir_path="$(cat "${lib__store_dir}/users_home_dir" 2>/dev/null || echo "" | xargs)"
  if [[ -z "${home_dir_path}" ]]; then
    return 1
  fi
  echo "${home_dir_path}"
}
export -f lib.home_dir_path

lib.panics_add() {
  local msg="$(cat)"
  local key="${1}"
  if [[ -z ${key} ]]; then
    echo "Failed to panic: no key supplied" >&2
    return 1
  fi
  local timestamp="$(date +"%Y-%m-%dT%H:%M:%S")"
  local panicfile="${lib__panics_dir}/${key}"
  mkdir -p "${lib__panics_dir}"
  cat <<EOF >"${panicfile}"
MESSAGE:

${msg}

TIME: ${timestamp}
EOF
}
export -f lib.panics_add

lib.panics_clear() {
  if [[ ! -d "${lib__panics_dir}" ]]; then
    return 1
  fi
  local panic_count="$(ls -A1 "${lib__panics_dir}" | wc -l)"
  if [[ ${panic_count} -eq 0 ]]; then
    return 1
  fi
  rm -rf "${lib__panics_dir}"
  mkdir -p "${lib__panics_dir}"
  return 0
}
export -f lib.panics_clear

lib.panics_print_all() {
  local panic_files="$(ls -A1 "${lib__panics_dir}" 2>/dev/null)"
  if [[ -z ${panic_files} ]]; then
    return 1
  fi
  while IFS= read -r panicfile; do
    cat "${lib__panics_dir}/${panicfile}"
  done <<<"${panic_files}"
}
export -f lib.panics_print_all

lib.use_host() {
  local filename="${1}"
  local host="$(lib.home_dir_path)"
  echo "${filename/\/root/${host}}"
}
export -f lib.use_host
