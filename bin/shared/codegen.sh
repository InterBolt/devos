#!/usr/bin/env bash

set -o pipefail
set -o errtrace

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 1

# shellcheck source=cant-source.sh
. shared/cant-source.sh

# shellcheck source=log.sh
. shared/log.sh

vLIB_CODEGEN_GIT_DIR="$(git rev-parse --show-toplevel &>/dev/null)"
vLIB_CODEGEN_BIN_DIR=""
vLIB_CODEGEN_SOURCE_FILENAME=""

codegen.allowed() {
  if [[ -z ${vLIB_CODEGEN_GIT_DIR} ]]; then
    return 1
  fi
  vLIB_CODEGEN_BIN_DIR="${vLIB_CODEGEN_GIT_DIR}/bin"
  if [[ ! -d ${vLIB_CODEGEN_BIN_DIR} ]]; then
    return 1
  fi
  vLIB_CODEGEN_SOURCE_FILENAME="__source__.sh"
  return 0
}

codegen.source_relative_files() {
  local dirname="${1}"
  local dir="${vLIB_CODEGEN_BIN_DIR}/${dirname}"
  if [[ ! -d ${dir} ]]; then
    log.error "A valid directory was not provided."
    exit 1
  fi
  local tmp_sourced_file="$(mktemp 2>/dev/null)"
  local exports_file="${dir}/${vLIB_CODEGEN_SOURCE_FILENAME}"
  echo "#!/usr/bin/env bash" >"${tmp_sourced_file}"
  echo "" >>"${tmp_sourced_file}"
  for file in "${dir}"/*.sh; do
    if [[ ! -f ${file} ]]; then
      continue
    fi
    local filename=$(basename "${file}")
    if [[ ${filename} = "${vLIB_CODEGEN_SOURCE_FILENAME}" ]]; then
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
  log.info "Generated ${vLIB_CODEGEN_SOURCE_FILENAME} files for all directories."
fi
