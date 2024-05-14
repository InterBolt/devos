#!/usr/bin/env bash

. cli/usage.sh

cli.parse._is_valid_help_command() {
  if [[ $1 = "--help" ]] || [[ $1 = "-h" ]] || [[ $1 = "help" ]]; then
    echo "true"
  else
    echo "false"
  fi
}
cli.parse.cmd() {
  if [[ -z "$1" ]]; then
    log_error "No command supplied."
    cli.usage.help
    exit 0
  fi
  if [[ $(cli.parse._is_valid_help_command "$1") = true ]]; then
    cli.usage.help
    exit 0
  fi
  local post_command_arg_index=0
  while [[ "$#" -gt 0 ]]; do
    if [[ $(cli.parse._is_valid_help_command "$1") = true ]]; then
      if [[ -z "${vCLI_CMD}" ]]; then
        log_error "invalid command, use \`solos --help\` to see available commands."
        exit 1
      fi
      cli.usage.command."${vCLI_CMD}".help
      exit 0
    fi
    case "$1" in
    --*)
      local key=$(echo "$1" | awk -F '=' '{print $1}' | sed 's/^--//')
      local value=$(echo "$1" | awk -F '=' '{print $2}')
      vCLI_OPTIONS+=("${key}=${value}")
      ;;
    *)
      if [[ -z "$1" ]]; then
        break
      fi
      if [[ -n "${vCLI_CMD}" ]]; then
        post_command_arg_index=$((post_command_arg_index + 1))
        vCLI_OPTIONS+=("argv${post_command_arg_index}=$1")
        break
      fi
      local cmd_name=$(echo "$1" | tr '-' '_')
      local is_allowed=false
      for allowed_cmd_name in "${vSELF_CLI_USAGE_ALLOWS_CMDS[@]}"; do
        if [[ ${cmd_name} = ${allowed_cmd_name} ]]; then
          is_allowed=true
        fi
      done
      if [[ ${is_allowed} = "false" ]]; then
        log_error "Unknown command: $1"
      else
        vCLI_CMD="${cmd_name}"
      fi
      ;;
    esac
    shift
  done
}
cli.parse.requirements() {
  for cmd_name in $(
    cli.usage.help |
      grep -A 1000 "${vSELF_CLI_USAGE_CMD_HEADER}" |
      grep -v "${vSELF_CLI_USAGE_CMD_HEADER}" |
      grep -E "^[a-z]" |
      awk '{print $1}'
  ); do
    cmd_name=$(echo "${cmd_name}" | tr '-' '_')
    if [[ "${cmd_name}" != "help" ]]; then
      vSELF_CLI_USAGE_ALLOWS_CMDS+=("${cmd_name}")
    fi
  done
  for cmd in "${vSELF_CLI_USAGE_ALLOWS_CMDS[@]}"; do
    opts="${cmd}("
    first=true
    for cmd_option in $(cli.usage.command."${cmd}".help | grep -E "^--" | awk '{print $1}'); do
      cmd_option="$(echo "${cmd_option}" | awk -F '=' '{print $1}' | sed 's/^--//')"
      if [[ ${first} = true ]]; then
        opts="${opts}${cmd_option}"
      else
        opts="${opts},${cmd_option}"
      fi
      first=false
    done
    vSELF_CLI_USAGE_ALLOWS_OPTIONS+=("${opts})")
  done
}
cli.parse.validate_opts() {
  if [[ -n ${vCLI_OPTIONS[0]} ]]; then
    for cmd_option in "${vCLI_OPTIONS[@]}"; do
      for allowed_cmd_option in "${vSELF_CLI_USAGE_ALLOWS_OPTIONS[@]}"; do
        cmd_name=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $1}')
        cmd_options=$(echo "${allowed_cmd_option}" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
        if [[ ${cmd_name} = ${vCLI_CMD} ]]; then
          is_cmd_option_allowed=false
          flag_name="$(echo "${cmd_option}" | awk -F '=' '{print $1}')"
          for cmd_option in "$(echo "${cmd_options}" | tr ',' '\n')"; do
            if [[ ${cmd_option} = ${flag_name} ]]; then
              is_cmd_option_allowed=true
            fi
          done
          if [[ ${flag_name} = "argv"* ]]; then
            is_cmd_option_allowed=true
          fi
          if [[ ${is_cmd_option_allowed} = false ]]; then
            echo ""
            echo "Command option: ${cmd_option} is not allowed for command: ${vCLI_CMD}."
            echo ""
            exit 1
          fi
        fi
      done
    done
  fi
}
