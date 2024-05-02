#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../bin.sh
. shared/empty.sh
# shellcheck source=../pkg/gum.sh
. shared/empty.sh

lib.utils.echo_line() {
  terminal_width=$(tput cols)
  line=$(printf "%${terminal_width}s" | tr " " "-")
  echo "$line"
}
lib.utils.generate_secret() {
  openssl rand -base64 32 | tr -dc 'a-z0-9' | head -c 32
}
# Must generate a unique string, 10 characters that is URL safe.
lib.utils.generate_project_id() {
  date +%H:%M:%S:%N | sha256sum | base64 | tr '[:upper:]' '[:lower:]' | head -c 16
}
lib.utils.get_project_id() {
  local project_id_file="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/id"
  if [[ -f ${project_id_file} ]]; then
    cat "${project_id_file}"
  else
    echo ""
  fi
}
# Any variable that is set in this shell will automatically replace any text matching:
# __<VARIABLE_NAME>__ in any file that is passed to this function.
lib.utils.template_variables() {
  local dir_or_file="$1"
  local eligible_files=()
  if [[ -d ${dir_or_file} ]]; then
    for file in "${dir_or_file}"/*; do
      if [[ -d ${file} ]]; then
        lib.utils.template_variables "${file}"
      fi
      if [[ -f ${file} ]]; then
        eligible_files+=("${file}")
      fi
    done
  elif [[ -f ${dir_or_file} ]]; then
    eligible_files+=("${dir_or_file}")
  fi
  if [[ ${#eligible_files[@]} -eq 0 ]]; then
    return
  fi
  local errored=false
  for file in "${eligible_files[@]}"; do
    bin_vars=$(grep -oE "__v[A-Z0-9_]*__" "${file}" || echo "" | sed 's/__//g')
    for bin_var in ${bin_vars}; do
      if [[ -z ${!bin_var+x} ]]; then
        log.error "Template variables error: ${file} is using an unset variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ -z ${!bin_var} ]]; then
        log.error "Template variables error: ${file} is using an empty variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ ${errored} = "false" ]] && [[ ${behavior} = "commit" ]]; then
        sed -i '' "s,\_\_${bin_var}\_\_,${!bin_var},g" "${file}"
      fi
    done
  done
  if [[ ${errored} = "true" ]]; then
    exit 1
  fi
}
lib.utils.full_date() {
  date +"%Y-%m-%d %H:%M:%S"
}
lib.utils.curl() {
  vPREV_CURL_ERR_STATUS_CODE=""
  vPREV_CURL_ERR_MESSAGE=""
  vPREV_CURL_RESPONSE=$(
    curl --silent --show-error "$@"
  )
  local error_message="$(jq -r '.error' <<<"${vPREV_CURL_RESPONSE}")"
  if [[ ${error_message} = "null" ]]; then
    echo ""
    return
  fi
  vPREV_CURL_ERR_MESSAGE="${error_message}"
  vPREV_CURL_ERR_STATUS_CODE="$(jq -r '.status' <<<"${vPREV_CURL_RESPONSE}")"
}
# shellcheck disable=SC2120
lib.utils.curl.allows_error_status_codes() {
  # A note on the "none" argument:
  # The benefit of forcing the caller to "say" their intention rather
  # than just leaving the arg list empty is purely for readability.
  if [[ -z $1 ]]; then
    log.error "Missing \`none\` or a list of allowed status codes."
    exit 1
  fi
  local error_message="${vPREV_CURL_ERR_MESSAGE} with status code: ${vPREV_CURL_ERR_STATUS_CODE}"
  local allowed="true"
  if [[ -z ${vPREV_CURL_ERR_STATUS_CODE} ]]; then
    log.info "no error status code found for curl request"
    return
  fi
  if [[ $1 = "none" ]]; then
    allowed=""
    shift
  fi
  local allowed_status_codes=()
  if [[ $# -gt 0 ]]; then
    allowed_status_codes=("$@")
  fi
  for allowed_status_code in "${allowed_status_codes[@]}"; do
    if [[ ${vPREV_CURL_ERR_STATUS_CODE} = "${allowed_status_code}" ]]; then
      allowed="true"
      log.info "set allowed to true for status code: ${allowed_status_code}"
    fi
  done
  if [[ -z ${allowed} ]]; then
    log.error "${error_message}"
    exit 1
  else
    log.warn "Allowing error status code: ${vPREV_CURL_ERR_STATUS_CODE} with message: ${vPREV_CURL_ERR_MESSAGE}"
  fi
}
lib.utils.heredoc() {
  local heredoc="$1"
  cat "${vSTATIC_SRC_DIR}/bin/heredocs/${heredoc}"
}
lib.utils.validate_fs() {
  local errors=()
  local return_code=0
  local parent_dir="$1"
  shift
  local children=("$@")
  for child in "${children[@]}"; do
    local type="${child%%:*}"
    local name="${child#*:}"
    local path="${parent_dir}/${name}"
    if [[ "${type}" == "dir" ]]; then
      if [[ ! -d "${path}" ]]; then
        errors+=("${path} is not a directory")
        return_code=1
      fi
    elif [[ "${type}" == "file" ]]; then
      if [[ ! -f "${path}" ]]; then
        errors+=("${path} is not a file")
        return_code=1
      fi
    else
      errors+=("unknown type: ${type}")
      return_code=1
    fi
  done
  for error in "${errors[@]}"; do
    log.error "${error}"
  done
  return ${return_code}
}
lib.utils.validate_interfaces() {
  local target_dir="$1"
  local interface_file="$1/$2"
  if [[ ! -d ${target_dir} ]]; then
    log.error "Unexpected error: ${target_dir} is not a directory. Failed to validate interfaces."
    exit 1
  fi
  if [[ ! -f "${interface_file}" ]]; then
    log.error "Unexpected error: ${interface_file} was not found. Failed to validate interfaces."
    exit 1
  fi

  # Collect the files in the target dir.
  local filenames=()
  for file in "${target_dir}"/*; do
    if [[ ! -f ${file} ]]; then
      continue
    fi
    local filename=$(basename "${file}")
    # All "special" files in SolOS follow the pattern __<name>__.<ext>
    # So we skip those since they live outside of our interface assumptions.
    if [[ ${filename} = "__"* ]]; then
      continue
    fi
    filenames+=("${filename}")
  done

  # Collect the expected methods from the interface file.
  local expected_methods=()
  while IFS= read -r line; do
    expected_methods+=("${line}")
  done <"${interface_file}"

  # Determine which files are invalid, if any, and log which methods
  # in particular are either invalid or missing
  local invalid_files=()
  for filename in "${filenames[@]}"; do
    local is_invalid=false
    local name="${filename%.*}"
    name="${name//-/_}"
    local prefix="${dir}.${name}"
    local cmds=("${@:2}")
    for cmd in "${expected_methods[@]}"; do
      if ! declare -f "${prefix}.${cmd}" >/dev/null; then
        log.error "${prefix}.${cmd} doesn't exist."
        is_invalid=true
      fi
    done
    if [[ ${is_invalid} = true ]]; then
      invalid_files+=("${filename}")
    fi
  done
  for invalid_file in "${invalid_files[@]}"; do
    log.error "${invalid_file} does not implement the interface."
  done

  local invalid_file_count="${#invalid_files[@]}"
  if [[ ${invalid_file_count} -gt 0 ]]; then
    log.error "Found ${invalid_file_count} invalid files."
    exit 1
  fi
}
