#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
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
    log.error "Failed to specify behavior for template variable substitution. Exiting."
    exit 1
  fi
  if [[ "$behavior" != "dry" ]] && [[ "$behavior" != "commit" ]]; then
    log.error "Template variable substitution behavior must be either 'dry' or 'commit'. Exiting."
    exit 1
  fi
  #
  # Note: don't fail on an empty directory, because we expect that to happen.
  # due the recursive nature of this function.
  #
  if [[ -d $dir_or_file ]]; then
    for file in "${dir_or_file}"/*; do
      if [[ -d $file ]]; then
        lib.utils.template_variables "$file" "$2"
      fi
      if [[ -f $file ]]; then
        eligible_files+=("$file")
      fi
    done
  elif [[ -f $dir_or_file ]]; then
    eligible_files+=("$dir_or_file")
  fi
  #
  # Terminating condition for the recursive function.
  #
  if [[ ${#eligible_files[@]} -eq 0 ]]; then
    return
  fi
  local errored=false
  for file in "${eligible_files[@]}"; do
    bin_vars=$(grep -oE "__v[A-Z0-9_]*__" "${file}" || echo "" | sed 's/__//g')
    for bin_var in $bin_vars; do
      if [[ -z ${!bin_var+x} ]]; then
        log.error "${file} is using an unset variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ ${empty_behavior} = "fail_on_empty" ]] && [[ -z ${!bin_var} ]]; then
        log.error "${file} is using an empty variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ ${errored} = "false" ]] && [[ ${behavior} = "commit" ]]; then
        log.info "replacing ${bin_var} with ${!bin_var} in ${file}"
        sed -i '' "s,\_\_${bin_var}\_\_,${!bin_var},g" "${file}"
        log.info "success: replaced ${bin_var} with ${!bin_var} in ${file}"
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
  local error_message="$(jq -r '.error' <<<"$vPREV_CURL_RESPONSE")"
  if [[ $error_message = "null" ]]; then
    echo ""
    return
  fi
  vPREV_CURL_ERR_MESSAGE="$error_message"
  vPREV_CURL_ERR_STATUS_CODE="$(jq -r '.status' <<<"$vPREV_CURL_RESPONSE")"
}

# shellcheck disable=SC2120
lib.utils.curl.allows_error_status_codes() {
  #
  # A note on the "none" argument:
  # The benefit of forcing the caller to "say" their intention rather
  # than just leaving the arg list empty is purely for readability.
  #
  if [[ -z $1 ]]; then
    log.error "Missing \`none\` or a list of allowed status codes."
    exit 1
  fi
  local error_message="error: ${vPREV_CURL_ERR_MESSAGE} with status code: ${vPREV_CURL_ERR_STATUS_CODE}"
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

lib.utils.warn_with_delay() {
  local message="$1"
  if [[ -z ${message} ]]; then
    log.error "Please provide a message to warn the user of. Exiting."
    exit 1
  fi
  log.warn "(5) ${message}"
  sleep 1
  log.warn "(4) ${message}"
  sleep 1
  log.warn "(3) ${message}"
  sleep 1
  log.warn "(2) ${message}"
  sleep 1
  log.warn "(1) ${message}"
  sleep 1

  log.info "Continuing..."
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

lib.utils.spinner() {
  # make sure we use non-unicode character type locale
  # (that way it works for any locale as long as the font supports the characters)
  local LC_CTYPE=C
  local start_linecount=$(wc -l <"${vSTATIC_LOG_FILEPATH}" | xargs)
  local start_seconds="${SECONDS}"

  local pid=$1 # Process Id of the previous running command
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  local charwidth=3
  local prefix="${2:-""}"
  if [[ -n ${prefix} ]]; then
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
    # WORK: why this work?
    last_line=${last_line#*INFO }
    last_line=${last_line% source=*}
    #
    # This should always match up with the info level color!
    #
    printf "%b" "${spin:$i:$charwidth} \e[94m${prefix}\e[0m ${last_line}"
    echo -n "\033[$((length_of_line + 2))D"
    sleep .1
  done
  echo -n "\033[K"
  tput cnorm
  wait "${pid}"
  local code=$?
  if [[ $code -ne 0 ]]; then
    vSOLOS_USE_FOREGROUND_LOGS=true
    #
    # Grab the times first for max accuracy.
    #
    local every_log_seconds_elapsed=$((SECONDS - vSOLOS_STARTED_AT))
    local subset_seconds_elapsed=$((start_seconds - vSOLOS_STARTED_AT))
    #
    # We don't need to worry about this affecting unrelated code because by this
    # point in the function, we know we're going to exit with an error code.
    #
    set -o errexit

    local terminal_line_number="$(wc -l <"${vSTATIC_LOG_FILEPATH}" | xargs)"
    local subset_label="logs created by previously failed command"
    local subset_header="Choose which set of logs to view:"
    local every_log="$(
      lib.utils.logdiff \
        "${vSTATIC_LOG_FILEPATH}" \
        "${vSOLOS_LOG_LINE_COUNT}" \
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
    if [[ ${choice} = "${subset_logs_choice}" ]]; then
      pkg.gum.logs_box \
        "Viewing ${subset_label} [${vSTATIC_LOG_FILEPATH}$newline:${start_linecount}]" \
        "Tip: use --foreground next time to see logs in real-time.${newline}" \
        "${subset_logs}"
    elif [[ ${choice} = "${every_log_choice}" ]]; then
      pkg.gum.logs_box \
        "Viewing all logs [${vSTATIC_LOG_FILEPATH}:${start_linecount}]$newline" \
        "Tip: use --foreground next time to see logs in real-time.${newline}" \
        "${every_log}"
    elif [[ ${choice} = "NONE" ]]; then
      log.warn "Review manually at [${vSTATIC_LOG_FILEPATH}:${start_linecount}] or supply the --foreground flag next time. Exiting."
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
  if [[ $vSOLOS_USE_FOREGROUND_LOGS = false ]]; then
    "$task" "$@" &
    local task_pid=$!
    lib.utils.spinner "${task_pid}" "${description}"
  else
    log.info "$description"
    "$task" "$@"
  fi
}
