#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=solos.sh
. "shared/empty.sh"
# shellcheck source=lib.utils.sh
. "shared/empty.sh"
# shellcheck source=shared/static.sh
. "shared/empty.sh"

lib.utils.echo_line() {
  terminal_width=$(tput cols)
  line=$(printf "%${terminal_width}s" | tr " " "-")
  echo "$line"
}
lib.utils.exit_trap() {
  local code=$?
  if [ $code -eq 1 ]; then
    exit 1
  fi
  exit $code
}
lib.utils.generate_secret() {
  openssl rand -base64 32 | tr -dc 'a-z0-9' | head -c 32
}
#
# This function is used to inject global variables into template files.
# It will search for all instances of __[_A-Z]*__ in the file and replace them with the
# corresponding global variable. If the global variable is not set, it will exit with an error.
# If the behavior is set to "commit", it will replace the variables in the file.
# If the behavior is set to "dry", it will only check if the variables are set.
#
lib.utils.template_variables() {
  local dir_or_file="$1"
  local behavior="$2"
  local empty_behavior="{$3:-fail_on_empty}"
  local eligible_files=()
  if [ -z "$behavior" ]; then
    log.error "lib.utils.template_variables: behavior cannot be empty"
    exit 1
  fi
  if [ "$behavior" != "dry" ] && [ "$behavior" != "commit" ]; then
    log.error "lib.utils.template_variables: \$2 must equal either \"dry\" or \"commit\""
    exit 1
  fi
  #
  # Note: don't fail on an empty directory, because we expect that to happen.
  # due the recursive nature of this function.
  #
  if [ -d "$dir_or_file" ]; then
    for file in "$dir_or_file"/*; do
      if [ -d "$file" ]; then
        lib.utils.template_variables "$file" "$2"
      fi
      if [ -f "$file" ]; then
        eligible_files+=("$file")
      fi
    done
  elif [ -f "$dir_or_file" ]; then
    eligible_files+=("$dir_or_file")
  fi
  #
  # Terminating condition for the recursive function.
  #
  if [ "${#eligible_files[@]}" -eq 0 ]; then
    return
  fi
  local errored=false
  for file in "${eligible_files[@]}"; do
    grepped=$(grep -o "__v[_A-Z]*__" "$file" || echo "")
    for line in $grepped; do
      local var_names="${line//____/__  __}"
      for var_name in ${var_names}; do
        var_name=${var_name//__/}
        if [ -z "${var_name// /}" ]; then
          continue
        fi
        if [ -z ${!var_name+x} ]; then
          echo "var_name: $var_name"
          log.error "$file is using an undefined variable: $var_name"
          errored=true
          continue
        fi
        if [ "$empty_behavior" == "fail_on_empty" ] && [ -z "${!var_name}" ]; then
          log.error "$file is using an empty variable: $var_name"
          errored=true
          continue
        fi
        if [ "$errored" == false ]; then
          log.debug "found $var_name in $file"
        fi
        if [ "$errored" == "false" ] && [ "$behavior" == "commit" ]; then
          sed -i '' "s,\_\_$var_name\_\_,${!var_name},g" "$file"
        fi
      done
    done
  done
  if [ "$errored" == "true" ]; then
    exit 1
  fi
}
lib.utils.date() {
  date +"%Y-%m-%d %H:%M:%S"
}
lib.utils.grep_global_vars() {
  grep -Eo 'v[A-Z0-9_]{2,}' "$1" | grep -v "#" || echo ""
}
lib.utils.files_match_dir() {
  local dir_to_match="$1"
  if [ ! -d "$dir_to_match" ]; then
    log.error "directory does not exist: $dir_to_match"
    exit 1
  fi
  local files_to_match=("${@:2}")
  for file_to_match in "${files_to_match[@]}"; do
    if [ ! -f "$dir_to_match/$file_to_match" ]; then
      log.error "bootfile does not exist: $dir_to_match/$file_to_match"
      exit 1
    fi
  done
  for dir_file in "$dir_to_match"/*; do
    if [ ! -f "$dir_file" ]; then
      continue
    fi
    dir_filename="$(basename "$dir_file")"
    found=false
    for file_to_match in "${files_to_match[@]}"; do
      if [ "$file_to_match" == "$dir_filename" ]; then
        found=true
      fi
    done
    if [ "$found" == false ]; then
      log.error "(${files_to_match[*]}) does not contain: $dir_filename"
      exit 1
    fi
  done
}
lib.utils.curl() {
  vPREV_CURL_ERR_STATUS_CODE=""
  vPREV_CURL_ERR_MESSAGE=""
  vPREV_CURL_RESPONSE=$(
    curl --silent --show-error "$@"
  )
  local error_message="$(jq -r '.error' <<<"$vPREV_CURL_RESPONSE")"
  if [ "$error_message" == "null" ]; then
    echo ""
    return
  fi
  vPREV_CURL_ERR_MESSAGE="$error_message"
  vPREV_CURL_ERR_STATUS_CODE="$(jq -r '.status' <<<"$vPREV_CURL_RESPONSE")"
}
# shellcheck disable=SC2120
lib.utils.curl.allows_error_status_codes() {
  #
  # The benefit of forcing the caller to "say" their intention rather
  # than just leaving the arg list empty is purely for readability.
  #
  if [ -z "$1" ]; then
    log.error "must declare \`none\` or a list of allowed status codes."
    exit 1
  fi
  local error_message="error: $vPREV_CURL_ERR_MESSAGE with status code: $vPREV_CURL_ERR_STATUS_CODE"
  local allowed="true"
  if [ -z "$vPREV_CURL_ERR_STATUS_CODE" ]; then
    log.debug "no error status code found for curl request"
    return
  fi
  if [ "$1" == "none" ]; then
    allowed=""
    shift
  fi
  local allowed_status_codes=()
  if [ "$#" -gt 0 ]; then
    allowed_status_codes=("$@")
  fi
  for allowed_status_code in "${allowed_status_codes[@]}"; do
    if [ "$vPREV_CURL_ERR_STATUS_CODE" == "$allowed_status_code" ]; then
      allowed="true"
      log.debug "set allowed to true for status code: $allowed_status_code"
    fi
  done
  if [ -z "$allowed" ]; then
    log.error "$error_message"
    exit 1
  else
    log.debug "allowed status code: $vPREV_CURL_ERR_STATUS_CODE"
    log.debug "with error message: $vPREV_CURL_ERR_MESSAGE"
  fi
}
lib.utils.warn_with_delay() {
  local message="$1"
  if [ -z "$message" ]; then
    log.error "message must not be empty. Exiting."
    exit 1
  fi
  log.warn "$message in 5 seconds."
  sleep 3
  log.warn "$message in 2 seconds."
  sleep 2
  log.warn "$message here we go..."
  sleep 1
}
