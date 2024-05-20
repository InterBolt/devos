#!/usr/bin/env bash

lib.utils.generate_secret() {
  openssl rand -base64 32 | tr -dc 'a-z0-9' | head -c 32
}
# Must generate a unique string, 10 characters that is URL safe.
lib.utils.generate_project_id() {
  date +%H:%M:%S:%N | sha256sum | base64 | tr '[:upper:]' '[:lower:]' | head -c 16
}
lib.utils.get_project_id() {
  local project_id_file="${HOME}/.solos/projects/${vPROJECT_NAME}/id"
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
    bin_vars=$(grep -o "__v[A-Z0-9_]*__" "${file}" | sed 's/__//g')
    for bin_var in ${bin_vars}; do
      if [[ -z ${!bin_var+x} ]]; then
        log_error "Template variables error: ${file} is using an unset variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ -z ${!bin_var} ]]; then
        log_error "Template variables error: ${file} is using an empty variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ ${errored} = "false" ]]; then
        sed -i "s,__${bin_var}__,${!bin_var},g" "${file}"
      fi
    done
  done
  if [[ ${errored} = "true" ]]; then
    exit 1
  fi
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
lib.utils.curl.allows_error_status_codes() {
  # A note on the "none" argument:
  # The benefit of forcing the caller to "say" their intention rather
  # than just leaving the arg list empty is purely for readability.
  if [[ -z $1 ]]; then
    log_error "Missing \`none\` or a list of allowed status codes."
    exit 1
  fi
  local error_message="${vPREV_CURL_ERR_MESSAGE} with status code: ${vPREV_CURL_ERR_STATUS_CODE}"
  local allowed="true"
  if [[ -z ${vPREV_CURL_ERR_STATUS_CODE} ]]; then
    log_info "no error status code found for curl request"
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
      log_info "set allowed to true for status code: ${allowed_status_code}"
    fi
  done
  if [[ -z ${allowed} ]]; then
    log_error "${error_message}"
    exit 1
  else
    log_warn "Allowing error status code: ${vPREV_CURL_ERR_STATUS_CODE} with message: ${vPREV_CURL_ERR_MESSAGE}"
  fi
}
