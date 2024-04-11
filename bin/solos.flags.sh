#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=solos.sh
. "shared/empty.sh"
# shellcheck source=solos.utils.sh
. "shared/empty.sh"
# shellcheck source=shared/static.sh
. "shared/empty.sh"
#
# Lib only vars - must always begin with LIB_*
#
LIB_FLAGS_HEADER_AVAILABLE_COMMANDS="Available commands:"
LIB_FLAGS_HEADER_AVAILABLE_OPTIONS="Available options:"
#
# Print top level usage information
#
flags.help() {
  cat <<EOF
Usage: solos command [--OPTS...]

The SolOS installer CLI to manage SolOS installations on your local computer or dev container.

$LIB_FLAGS_HEADER_AVAILABLE_COMMANDS

help                     - Print this help and exit
launch                   - Launch a SolOS project.
checkout                 - Checkout a project directory to avoid having to provide the directory
                           on every command.
status                   - Print the status of a SolOS project.
sync-config              - Sync the \`.solos\` config folder to the remote server.
backup                   - Archive a SolOS project and upload it to an s3 bucket.
restore                  - Restore a SolOS project from an s3 bucket.
code                     - Open the VSCode workspaces associated with the installation.
precheck                 - (for dev) Run some prechecks to verify any assumptions made by the solos script.
tests                    - (for dev) Generates unit tests for each solos.* library.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--help                   - Print this help and exit

Source: https://github.com/InterBolt/solos
EOF
}
#
# Print launch command usage information
#
flags.command.launch.help() {
  cat <<EOF
Usage: solos launch [--OPTS...]

Launch a new installation, complete a partial installation, or repair an existing installation.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--server            - The type of server to bootstrap. (default: $vSTATIC_DEFAULT_SERVER)
--help              - Print this help and exit
--hard-reset        - Dangerously recreate project files and infrastructure.
--clear-cache       - Clear the cache and ignore previously stored values.
EOF
}
#
# Print sync-config command usage information
#
flags.command.sync_config.help() {
  cat <<EOF
Usage: solos sync-config [--OPTS...]

Sync the .solos config folder to the remote server.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
EOF
}
#
# Print sync-config command usage information
#
flags.command.status.help() {
  cat <<EOF
Usage: solos status [--OPTS...]

Print the status of a solos project.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
EOF
}
flags.command.tests.help() {
  cat <<EOF
Usage: solos tests [--OPTS...]

Run tests on either a specific library or all solos.* libraries.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--lib               - (ex: "ssh" tests "solos.ssh") The name of the library to test.
--help              - Print this help and exit
EOF
}
#
# Print checkout command usage information
#
flags.command.checkout.help() {
  cat <<EOF
Usage: solos checkout [--OPTS...]

Launch a new installation, complete a partial installation, or repair an existing installation.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
EOF
}
#
# Print launch command usage information
#
flags.command.code.help() {
  cat <<EOF
Usage: solos code [--OPTS...]

Open the vscode workspaces associated with the installation.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
EOF
}
flags.command.backup.help() {
  cat <<EOF
Usage: solos backup [--OPTS...]

Backup the installation, caprover, and postgres to the s3 bucket.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
--tag=<string>      - The tag to use for the backup.
EOF
}
flags.command.restore.help() {
  cat <<EOF
Usage: solos restore [--OPTS...]

Restore the installation, caprover, and postgres from the s3 bucket.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
--tag=<string>      - When supplied, we'll restore the latest backup that 
                      matches the tag. If no tag is supplied, we'll restore
                      the latest backup.
EOF
}
flags.command.precheck.help() {
  cat <<EOF
Usage: solos precheck [--OPTS...]

Performs as many checks as possible on the solos runtime to ensure it will work
as expected.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--help              - Print this help and exit
EOF
}
flags._is_valid_help_command() {
  if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
    echo "true"
  else
    echo "false"
  fi
}
flags.parse_cmd() {
  if [ -z "$1" ]; then
    log.error "No command supplied."
    flags.help
    exit 0
  fi
  if [ "$(flags._is_valid_help_command "$1")" == "true" ]; then
    flags.help
    exit 0
  fi
  while [ "$#" -gt 0 ]; do
    if [ "$(flags._is_valid_help_command "$1")" == "true" ]; then
      if [ -z "$vCLI_PARSED_CMD" ]; then
        log.error "invalid command, use \`solos --help\` to see available commands."
        exit 1
      fi
      flags."$vCLI_PARSED_CMD".help
      exit 0
    fi
    case "$1" in
    --*)
      local key=$(echo "$1" | awk -F '=' '{print $1}' | sed 's/^--//')
      local value=$(echo "$1" | awk -F '=' '{print $2}')
      vCLI_PARSED_OPTIONS+=("$key=$value")
      ;;
    *)
      if [ -z "$1" ]; then
        break
      fi
      local cmd_name=$(echo "$1" | tr '-' '_')
      local is_allowed=false
      for allowed_cmd_name in "${vCLI_USAGE_ALLOWS_CMDS[@]}"; do
        if [ "$cmd_name" == "$allowed_cmd_name" ]; then
          is_allowed=true
        fi
      done
      if [ "$is_allowed" == "false" ]; then
        log.error "Unknown command: $1"
      else
        vCLI_PARSED_CMD="$cmd_name"
      fi
      ;;
    esac
    shift
  done
}

flags.parse_requirements() {
  for cmd_name in $(
    flags.help |
      grep -A 1000 "$LIB_FLAGS_HEADER_AVAILABLE_COMMANDS" |
      grep -B 1000 "$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS" |
      grep -v "$LIB_FLAGS_HEADER_AVAILABLE_COMMANDS" |
      grep -v "$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS" |
      grep -E "^[a-z]" |
      awk '{print $1}'
  ); do
    cmd_name=$(echo "$cmd_name" | tr '-' '_')
    if [ "$cmd_name" != "help" ]; then
      vCLI_USAGE_ALLOWS_CMDS+=("$cmd_name")
    fi
  done
  for cmd in "${vCLI_USAGE_ALLOWS_CMDS[@]}"; do
    opts="$cmd("
    first=true
    for cmd_option in $(flags.command."$cmd".help | grep -E "^--" | awk '{print $1}'); do
      cmd_option=$(echo "$cmd_option" | awk -F '=' '{print $1}' | sed 's/^--//')
      if [ "$first" = true ]; then
        opts="$opts$cmd_option"
      else
        opts="$opts,$cmd_option"
      fi
      first=false
    done
    vCLI_USAGE_ALLOWS_OPTIONS+=("$opts)")
  done
}
flags.validate_options() {
  if [ -n "${vCLI_PARSED_OPTIONS[0]}" ]; then
    for parsed_cmd_option in "${vCLI_PARSED_OPTIONS[@]}"; do
      for allowed_cmd_option in "${vCLI_USAGE_ALLOWS_OPTIONS[@]}"; do
        cmd_name=$(echo "$allowed_cmd_option" | awk -F '(' '{print $1}')
        cmd_options=$(echo "$allowed_cmd_option" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
        if [ "$cmd_name" == "$vCLI_PARSED_CMD" ]; then
          is_cmd_option_allowed=false
          flag_name=$(echo "${parsed_cmd_option}" | awk -F '=' '{print $1}')
          for cmd_option in $(echo "$cmd_options" | tr ',' '\n'); do
            if [ "$cmd_option" == "$flag_name" ]; then
              is_cmd_option_allowed=true
            fi
          done
          if [ "$is_cmd_option_allowed" == false ]; then
            echo ""
            echo "Command option: ${parsed_cmd_option} is not allowed for command: $vCLI_PARSED_CMD."
            echo ""
            exit 1
          fi
        fi
      done
    done
  fi
}

flags.somefn() {
  echo "$vOTHER_VAR"
  echo "$vSOME_VAR"
}
