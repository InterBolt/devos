#!/usr/bin/env bash

set -o pipefail
set -o errtrace

# shellcheck source=must-source.sh
. shared/must-source.sh
# shellcheck source=log.sh
. shared/log.sh
# shellcheck source=static.sh
. shared/static.sh

shared.codegen._build_sources() {
  local dirname="${1}"
  local output_filename="${2}"
  local dir="${dirname}"
  if [[ ! -d ${dir} ]]; then
    log.error "A valid directory was not provided."
    exit 1
  fi
  local tmp_sourced_file="$(mktemp 2>/dev/null)"
  local exports_file="${dir}/${output_filename}"
  echo "#!/usr/bin/env bash" >"${tmp_sourced_file}"
  echo "" >>"${tmp_sourced_file}"
  for file in "${dir}"/*.sh; do
    if [[ ! -f ${file} ]]; then
      continue
    fi
    local filename=$(basename "${file}")
    if [[ ${filename} = "${output_filename}" ]]; then
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
  local source_filename="$1"
  local dirs=(
    "pkg"
    "cmd"
    "cli"
    "lib"
    "provision"
    "profile"
  )
  for dir in "${dirs[@]}"; do
    if ! shared.codegen._build_sources "${dir}" "${source_filename}"; then
      log.error "Failed to build ${dir}/${source_filename}"
      exit 1
    fi
  done
  log.info "Generated ${source_filename} files."
}
