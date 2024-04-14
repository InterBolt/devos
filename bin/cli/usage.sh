#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh
#
# Lib only vars - must always begin with LIB_*
#
LIB_FLAGS_HEADER_AVAILABLE_COMMANDS="Available commands:"
LIB_FLAGS_HEADER_AVAILABLE_OPTIONS="Available options:"
#
# Print top level usage information
#
cli.usage.help() {
  cat <<EOF
Usage: solos command [--OPTS...]

A CLI to manage SolOS projects on your local machine or container.

$LIB_FLAGS_HEADER_AVAILABLE_COMMANDS

help                     - Print this help and exit
launch                   - Launch a SolOS project.
checkout                 - Checkout a project directory to avoid having to provide the directory
                           on every command.
sync-config              - Sync the \`.solos\` config folder to a remote server. 
                           Use with caution!
backup                   - Archive a SolOS project and upload it to an s3 bucket.
restore                  - Restore a SolOS project from an s3 bucket. It is optional to 
                           override the config on your working machine.
code                     - Open the VSCode workspaces associated with the project.
test                     - (DEV ONLY) Generates and runs unit tests for each lib.* library.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--help                   - Print this help and exit
--foreground             - Avoids usage of the progress spinner and subshells so that logging happens in 
                           the foreground.

Source: https://github.com/InterBolt/solos
EOF
}
#
# Print launch command usage information
#
cli.usage.command.launch.help() {
  cat <<EOF
Usage: solos launch [--OPTS...]

Launches a new project, completes a partial project, or repairs an existing project.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--server            - The type of server to bootstrap. (default: $vSTATIC_DEFAULT_SERVER)
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
--hard-reset        - Dangerously recreate project files and infrastructure.
EOF
}
#
# Print sync-config command usage information
#
cli.usage.command.sync_config.help() {
  cat <<EOF
Usage: solos sync-config [--OPTS...]

Sync your machine's \`~/.solos\` (aka your global SolOS config) to the remote server.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
EOF
}
cli.usage.command.test.help() {
  cat <<EOF
Usage: solos test [--OPTS...]

DEV ONLY! Runs tests from within the SolOS source repository.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--lib               - (ex: "ssh" tests "lib.ssh") The name of the library to test.
--fn                - (ex: "lib.<category>.<fn>") The name of the lib function to test.
--help              - Print this help and exit
--foreground        - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
#
# Print checkout command usage information
#
cli.usage.command.checkout.help() {
  cat <<EOF
Usage: solos checkout [--OPTS...]

Sets the active project directory. Subsequent commands will use the supplied directory unless
the --dir option is explicitly provided.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
--foreground        - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
#
# Print launch command usage information
#
cli.usage.command.code.help() {
  cat <<EOF
Usage: solos code [--OPTS...]

Open the VSCode workspaces associated with the project.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
cli.usage.command.backup.help() {
  cat <<EOF
Usage: solos backup [--OPTS...]

Backup the project to an S3 compatible bucket.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
--tag=<string>      - The tag to use for the backup.
EOF
}
cli.usage.command.restore.help() {
  cat <<EOF
Usage: solos restore [--OPTS...]

Restore the project from an S3 compatible bucket.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--force-config      - Will overwrite your machine's config with the backup's config.
--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
--tag=<string>      - When supplied, we'll restore the latest backup that 
                      matches the tag. If no tag is supplied, we'll restore
                      the latest backup.
EOF
}
