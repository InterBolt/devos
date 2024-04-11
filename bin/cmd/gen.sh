#!/usr/bin/env bash

# TODO: remove this. was generated via snippet
set -o errexit
set -o pipefail
set -o errtrace
PARENT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
if [ "$(basename "${PARENT_PATH}")" == "bin" ]; then
  cd "${PARENT_PATH}"
fi
vFROM_BIN_SCRIPT="true"
# TODO: remove the above. was generated via snippet

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_SOURCE_DIRNAME="__source__.sh"

cmd.gen._exports() {
  local dir="$1"
  if [ ! -d "${dir}" ]; then
    log.error "A valid directory was not provided."
    exit 1
  fi
  local tmp_exports_file="$(mktemp 2>/dev/null)"
  local exports_file="${dir}/${LIB_SOURCE_DIRNAME}"
  echo "#!/usr/bin/env bash" >"${tmp_exports_file}"
  echo "" >>"${tmp_exports_file}"
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
      echo ". ${dir}/${filename}"
    } >>"${tmp_exports_file}"
  done
  rm -f "${exports_file}"
  cp "${tmp_exports_file}" "${exports_file}"
  rm -f "${tmp_exports_file}"
}

cmd.gen() {
  cmd.gen._exports "cmd"
  log.info "generated \`cmd\` __sourced__ script."
  cmd.gen._exports "cli"
  log.info "generated \`cli\` __sourced__ script."
  cmd.gen._exports "lib"
  log.info "generated \`lib\` __sourced__ script."
}

cmd.gen
