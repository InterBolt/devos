#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

lib.utils.echo_line() {
  terminal_width=$(tput cols)
  line=$(printf "%${terminal_width}s" | tr " " "-")
  echo "$line"
}
lib.utils.exit_trap() {
  tput cnorm
  local code=$?
  if [[ $code -eq 1 ]]; then
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
  if [[ -z "$behavior" ]]; then
    log.error "lib.utils.template_variables: behavior cannot be empty"
    exit 1
  fi
  if [[ "$behavior" != "dry" ]] && [[ "$behavior" != "commit" ]]; then
    log.error "lib.utils.template_variables: \$2 must equal either \"dry\" or \"commit\""
    exit 1
  fi
  #
  # Note: don't fail on an empty directory, because we expect that to happen.
  # due the recursive nature of this function.
  #
  if [[ -d "$dir_or_file" ]]; then
    for file in "$dir_or_file"/*; do
      if [[ -d "$file" ]]; then
        lib.utils.template_variables "$file" "$2"
      fi
      if [[ -f "$file" ]]; then
        eligible_files+=("$file")
      fi
    done
  elif [[ -f "$dir_or_file" ]]; then
    eligible_files+=("$dir_or_file")
  fi
  #
  # Terminating condition for the recursive function.
  #
  if [[ "${#eligible_files[@]}" -eq 0 ]]; then
    return
  fi
  local errored=false
  for file in "${eligible_files[@]}"; do
    grepped=$(grep -o "__v[_A-Z]*__" "$file" || echo "")
    for line in $grepped; do
      local var_names="${line//____/__  __}"
      for var_name in ${var_names}; do
        var_name=${var_name//__/}
        if [[ -z "${var_name// /}" ]]; then
          continue
        fi
        if [[ -z ${!var_name+x} ]]; then
          echo "var_name: $var_name"
          log.error "$file is using an undefined variable: $var_name"
          errored=true
          continue
        fi
        if [[ "$empty_behavior" = "fail_on_empty" ]] && [[ -z "${!var_name}" ]]; then
          log.error "$file is using an empty variable: $var_name"
          errored=true
          continue
        fi
        if [[ "$errored" = false ]]; then
          log.info "found $var_name in $file"
        fi
        if [[ "$errored" = "false" ]] && [[ "$behavior" = "commit" ]]; then
          sed -i '' "s,\_\_$var_name\_\_,${!var_name},g" "$file"
        fi
      done
    done
  done
  if [[ "$errored" = "true" ]]; then
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
  if [[ ! -d "$dir_to_match" ]]; then
    log.error "directory does not exist: $dir_to_match"
    exit 1
  fi
  local files_to_match=("${@:2}")
  for file_to_match in "${files_to_match[@]}"; do
    if [[ ! -f "$dir_to_match/$file_to_match" ]]; then
      log.error "bootfile does not exist: $dir_to_match/$file_to_match"
      exit 1
    fi
  done
  for dir_file in "$dir_to_match"/*; do
    if [[ ! -f "$dir_file" ]]; then
      continue
    fi
    dir_filename="$(basename "$dir_file")"
    found=false
    for file_to_match in "${files_to_match[@]}"; do
      if [[ "$file_to_match" = "$dir_filename" ]]; then
        found=true
      fi
    done
    if [[ "$found" = false ]]; then
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
  if [[ "$error_message" = "null" ]]; then
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
  if [[ -z "$1" ]]; then
    log.error "must declare \`none\` or a list of allowed status codes."
    exit 1
  fi
  local error_message="error: $vPREV_CURL_ERR_MESSAGE with status code: $vPREV_CURL_ERR_STATUS_CODE"
  local allowed="true"
  if [[ -z "$vPREV_CURL_ERR_STATUS_CODE" ]]; then
    log.info "no error status code found for curl request"
    return
  fi
  if [[ "$1" = "none" ]]; then
    allowed=""
    shift
  fi
  local allowed_status_codes=()
  if [[ "$#" -gt 0 ]]; then
    allowed_status_codes=("$@")
  fi
  for allowed_status_code in "${allowed_status_codes[@]}"; do
    if [[ "$vPREV_CURL_ERR_STATUS_CODE" = "$allowed_status_code" ]]; then
      allowed="true"
      log.info "set allowed to true for status code: $allowed_status_code"
    fi
  done
  if [[ -z "$allowed" ]]; then
    log.error "$error_message"
    exit 1
  else
    log.info "allowed status code: $vPREV_CURL_ERR_STATUS_CODE"
    log.info "with error message: $vPREV_CURL_ERR_MESSAGE"
  fi
}
lib.utils.warn_with_delay() {
  local message="$1"
  if [[ -z "$message" ]]; then
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

lib.utils.logdiff() {
  local filepath="$1"
  local start="$2"
  local end="$3"
  start=$(echo "$start" | xargs)
  end=$(echo "$end" | xargs)

  local logfile_diff=$((end - start))
  if [[ $logfile_diff -gt 0 ]]; then
    local chunk="$(tail -n $logfile_diff "$filepath")"
    local ORIGINAL_IFS=$IFS
    IFS=$'\n'
    for line in $chunk; do
      echo "$line"
    done
    IFS=$ORIGINAL_IFS
  else
    echo ""
  fi
}

lib.utils.from_hex() {
  hex=$1
  if [[ $hex == "#"* ]]; then
    hex=$(echo "$1" | awk '{print substr($0,2)}')
  fi
  r=$(printf '0x%0.2s' "$hex")
  g=$(printf '0x%0.2s' "${hex#??}")
  b=$(printf '0x%0.2s' "${hex#????}")
  echo -e "$(printf "%s" "$(((r < 75 ? 0 : (r - 35) / 40) * 6 * 6 + (g < 75 ? 0 : (g - 35) / 40) * 6 + (b < 75 ? 0 : (b - 35) / 40) + 16))")"
}

lib.utils.spinner() {
  # make sure we use non-unicode character type locale
  # (that way it works for any locale as long as the font supports the characters)
  local LC_CTYPE=C
  local start_linecount=$(wc -l <"${vSTATIC_LOG_FILEPATH}" | xargs)
  local start_seconds="$SECONDS"

  local pid=$1 # Process Id of the previous running command
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  local charwidth=3
  local prefix="${2:-""}"
  if [[ -n "${prefix}" ]]; then
    prefix="${prefix}: "
  fi
  local length_of_prefix=${#prefix}

  local i=0
  tput civis # cursor invisible
  while kill -0 "${pid}" 2>/dev/null; do
    local i=$(((charwidth + i) % ${#spin}))
    local last_line=$(tail -n 1 "${vSTATIC_LOG_FILEPATH}")
    local length_of_last_line=${#last_line}
    local length_of_line=$((length_of_last_line + length_of_prefix))

    last_line=${last_line#*INFO }
    last_line=${last_line% source=*}
    #
    # This should always match up with the info level color!
    #
    printf "%b" "${spin:$i:$charwidth} \e[94m${prefix}\e[0m ${last_line}"
    echo -en "\033[$((length_of_line + 2))D"
    sleep .1
  done
  echo -en "\033[K"
  tput cnorm
  wait "${pid}"
  local code=$?
  if [[ $code -ne 0 ]]; then
    vENTRY_FOREGROUND=true
    #
    # Grab the times first for max accuracy.
    #
    local every_log_seconds_elapsed=$((SECONDS - vENTRY_START_SECONDS))
    local subset_seconds_elapsed=$((start_seconds - vENTRY_START_SECONDS))
    #
    # We don't need to worry about this affecting unrelated code because by this
    # point in the function, we know we're going to exit with an error code.
    #
    set -o errexit
    #
    # Display choices where the user can either choose to view all of the logs
    # since the start of the latest SolOS run or a subset of things which can be described
    # via argument params.
    #
    # Note: when a start line number is not provided, we automatically log everything, skipping
    # the choice prompt.
    #
    local terminal_line_number="$(wc -l <"${vSTATIC_LOG_FILEPATH}" | xargs)"
    local subset_label="logs created by previously failed command"
    local subset_header="Choose which set of logs to view:"
    local every_log="$(
      lib.utils.logdiff \
        "${vSTATIC_LOG_FILEPATH}" \
        "${vENTRY_LOG_LINE_COUNT}" \
        "${terminal_line_number}"
    )"
    local subset_logs="$(
      lib.utils.logdiff \
        "${vSTATIC_LOG_FILEPATH}" \
        "${start_linecount}" \
        "${terminal_line_number}"
    )"
    pkg.gum.danger_box "Encountered an error. Use --foreground next time to see all log levels in real-time."
    local newline=$'\n'
    local subset_logs_choice="(1) View ${subset_label} (${subset_seconds_elapsed} seconds)"
    local every_log_choice="(2) View all logs (${every_log_seconds_elapsed} seconds)"
    local choice="$(
      pkg.gum choose \
        --cursor.foreground "#A0A" --header.foreground "#FFF" --selected.foreground "#3B78FF" \
        --header "${subset_header}" ''"${subset_logs_choice}"'' ''"${every_log_choice}"'' '(3) None'
    )"
    if [[ "$choice" = "${subset_logs_choice}" ]]; then
      pkg.gum.logs_box \
        "Viewing ${subset_label} [${vSTATIC_LOG_FILEPATH}$newline:${start_linecount}]" \
        "TIP: use --foreground next time to see logs in real-time." \
        "${subset_logs}"
    elif [[ "$choice" = "${every_log_choice}" ]]; then
      pkg.gum.logs_box \
        "Viewing all logs [${vSTATIC_LOG_FILEPATH}:${start_linecount}]$newline" \
        "TIP: use --foreground next time to see logs in real-time.${newline}" \
        "${every_log}"
    elif [[ "$choice" = "NONE" ]]; then
      log.warn "Review manually at ${vSTATIC_LOG_FILEPATH} or supply the --foreground flag next time. Exiting."
    fi
    exit $code
  fi
}

lib.utils.do_task() {
  local description="$1"
  local task="$2"
  shift 2
  if ! declare -f "$task" >/dev/null; then
    log.error "second argument must be the task function."
    exit 1
  fi
  if [[ $vENTRY_FOREGROUND = false ]]; then
    "$task" "$@" &
    local task_pid=$!
    lib.utils.spinner "${task_pid}" "${description}"
  else
    log.info "$description"
    "$task" "$@"
  fi
}
