#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(dirname "${BASH_SOURCE[0]}")"

# shellcheck source=log.sh
. log.sh
log.fallback_ready

LIB_GIT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$LIB_GIT_DIR" ]; then
  log.debug "must be run from within a git repository. Exiting"
  exit 1
fi
LIB_BIN_DIR="${LIB_GIT_DIR}/bin"
if [ ! -d "${LIB_BIN_DIR}" ]; then
  log.debug "${LIB_BIN_DIR} not found. Exiting."
  exit 1
fi
LIB_SOURCE_DIRNAME="__source__.sh"

codegen.source_relative_files() {
  local dirname="${1}"
  local dir="${LIB_BIN_DIR}/${dirname}"
  if [ ! -d "${dir}" ]; then
    log.debug "A valid directory was not provided."
    exit 1
  fi
  local tmp_sourced_file="$(mktemp 2>/dev/null)"
  local exports_file="${dir}/${LIB_SOURCE_DIRNAME}"
  echo "#!/usr/bin/env bash" >"${tmp_sourced_file}"
  echo "" >>"${tmp_sourced_file}"
  for file in "${dir}"/*.sh; do
    if [ ! -f "${file}" ]; then
      continue
    fi
    local filename=$(basename "${file}")
    if [ "${filename}" == "${LIB_SOURCE_DIRNAME}" ]; then
      continue
    fi
    {
      echo "# shellcheck source=${filename}"
      echo ". ${dirname}/${filename}"
    } >>"${tmp_sourced_file}"
  done
  rm -f "${exports_file}"
  cp "${tmp_sourced_file}" "${exports_file}"
  rm -f "${tmp_sourced_file}"
}

codegen.source_relative_files "cmd"
log.debug "generated ${LIB_BIN_DIR}/cmd/${LIB_SOURCE_DIRNAME}."
codegen.source_relative_files "cli"
log.debug "generated ${LIB_BIN_DIR}/cli/${LIB_SOURCE_DIRNAME}."
codegen.source_relative_files "lib"
log.debug "generated ${LIB_BIN_DIR}/lib/${LIB_SOURCE_DIRNAME}."
