#!/usr/bin/env bash

set -o pipefail
set -o errtrace

# shellcheck source=cant-source.sh
. shared/must-source.sh
# shellcheck source=log.sh
. shared/log.sh

vLIB_CODEGEN_EXPORTER_FILENAME="__source__.sh"

shared.codegen.source_relative_files() {
  local dirname="${1}"
  local dir="${dirname}"
  if [[ ! -d ${dir} ]]; then
    log.error "A valid directory was not provided."
    exit 1
  fi
  local tmp_sourced_file="$(mktemp 2>/dev/null)"
  local exports_file="${dir}/${vLIB_CODEGEN_EXPORTER_FILENAME}"
  echo "#!/usr/bin/env bash" >"${tmp_sourced_file}"
  echo "" >>"${tmp_sourced_file}"
  for file in "${dir}"/*.sh; do
    if [[ ! -f ${file} ]]; then
      continue
    fi
    local filename=$(basename "${file}")
    if [[ ${filename} = "${vLIB_CODEGEN_EXPORTER_FILENAME}" ]]; then
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

shared.codegen.run() {
  if ! shared.codegen.source_relative_files "pkg"; then
    log.error "Failed to generate source exporter file (__source__.sh) for pkg"
    exit 1
  fi
  if ! shared.codegen.source_relative_files "cmd"; then
    log.error "Failed to generate source exporter file (__source__.sh) for cmd"
    exit 1
  fi
  if ! shared.codegen.source_relative_files "cli"; then
    log.error "Failed to generate source exporter file (__source__.sh) for cli"
    exit 1
  fi
  if ! shared.codegen.source_relative_files "lib"; then
    log.error "Failed to generate source exporter file (__source__.sh) for lib"
    exit 1
  fi
  log.info "Generated ${vLIB_CODEGEN_EXPORTER_FILENAME} files for all directories."
}
