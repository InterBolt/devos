#!/usr/bin/env bash

set -o pipefail
set -o errtrace

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
LIB_ENTRY_DIR="$(pwd)"

cd ..
# shellcheck source=log.sh
. shared/log.sh

LIB_GIT_DIR="$(git rev-parse --show-toplevel &>/dev/null)"
LIB_BIN_DIR=""
LIB_SOURCE_DIRNAME=""

codegen.allowed() {
  if [[ -z "$LIB_GIT_DIR" ]]; then
    return 1
  fi
  LIB_BIN_DIR="${LIB_GIT_DIR}/bin"
  if [[ ! -d "${LIB_BIN_DIR}" ]]; then
    return 1
  fi
  LIB_SOURCE_DIRNAME="__source__.sh"
  return 0
}

codegen.source_relative_files() {
  local dirname="${1}"
  local dir="${LIB_BIN_DIR}/${dirname}"
  if [[ ! -d "${dir}" ]]; then
    log.error "A valid directory was not provided."
    exit 1
  fi
  local tmp_sourced_file="$(mktemp 2>/dev/null)"
  local exports_file="${dir}/${LIB_SOURCE_DIRNAME}"
  echo "#!/usr/bin/env bash" >"${tmp_sourced_file}"
  echo "" >>"${tmp_sourced_file}"
  for file in "${dir}"/*.sh; do
    if [[ ! -f "${file}" ]]; then
      continue
    fi
    local filename=$(basename "${file}")
    if [[ "${filename}" = "${LIB_SOURCE_DIRNAME}" ]]; then
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

if codegen.allowed; then
  codegen.source_relative_files "pkg"
  codegen.source_relative_files "cmd"
  codegen.source_relative_files "cli"
  codegen.source_relative_files "lib"
  log.info "generated ${LIB_SOURCE_DIRNAME} files"
fi
