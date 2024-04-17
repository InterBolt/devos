#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

lib.env.generate_files() {
  local tmp_dir="$(mktemp -d 2>/dev/null)"
  local bin_vars=$(grep -Eo 'v[A-Z0-9_]*' "${vMETA_BIN_FILEPATH}" | sort | uniq)
  for bin_var in $bin_vars; do
    local result="$(declare -p "${bin_var}" &>/dev/null && echo "set" || echo "unset")"
    if [[ ${result} = "unset" ]]; then
      log.error "Unset bin var: ${bin_var} detected. Refusing to build .env file. Exiting"
      exit 1
    else
      local bin_val=${!bin_var}
      if [[ -z ${bin_val} ]]; then
        log.error "${bin_var} is empty but we expect a non-empty value in order to build the .env file. Exiting."
        exit 1
      fi
      local found="$(grep -q "^${bin_var}=" "${vOPT_PROJECT_DIR}/${vSTATIC_ENV_FILENAME}" &>/dev/null && echo "found" || echo "")"
      if [[ -z "$found" ]]; then
        echo "${bin_var}=${bin_val}" >>"${tmp_dir}/${vSTATIC_ENV_FILENAME}"
        echo "export ${bin_var}=\"${bin_val}\"" >>"${tmp_dir}/${vSTATIC_ENV_SH_FILENAME}"
      fi
    fi
  done
  #
  # Wait until the files are built before moving them to their final location
  # in case we had to abort mid-loop.
  #
  rm -f "${vOPT_PROJECT_DIR}/${vSTATIC_ENV_SH_FILENAME}"
  rm -f "${vOPT_PROJECT_DIR}/${vSTATIC_ENV_FILENAME}"
  mv "${tmp_dir}/${vSTATIC_ENV_SH_FILENAME}" "${vOPT_PROJECT_DIR}/${vSTATIC_ENV_SH_FILENAME}"
  mv "${tmp_dir}/${vSTATIC_ENV_FILENAME}" "${vOPT_PROJECT_DIR}/${vSTATIC_ENV_FILENAME}"
  #
  # Cleanup tmp dir
  #
  rm -rf "${tmp_dir}"
}
