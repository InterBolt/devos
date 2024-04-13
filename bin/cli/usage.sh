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

The SolOS installer CLI to manage SolOS installations on your local computer or dev container.

$LIB_FLAGS_HEADER_AVAILABLE_COMMANDS

help                     - Print this help and exit
launch                   - Launch a SolOS project.
checkout                 - Checkout a project directory to avoid having to provide the directory
                           on every command.
sync-config              - Sync the \`.solos\` config folder to a remote server.
backup                   - Archive a SolOS project and upload it to an s3 bucket.
restore                  - Restore a SolOS project from an s3 bucket.
code                     - Open the VSCode workspaces associated with the installation.
precheck                 - (for dev) Run some prechecks to verify any assumptions made by the solos script.
tests                    - (for dev) Generates and runs unit tests for each lib.* library.
gen                      - (for dev) Generates source code.

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

Launch a new installation, complete a partial installation, or repair an existing installation.

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

Sync the .solos config folder to the remote server.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
EOF
}
cli.usage.command.tests.help() {
  cat <<EOF
Usage: solos tests [--OPTS...]

Run tests on either a specific library or all lib.* libraries.

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

Launch a new installation, complete a partial installation, or repair an existing installation.

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

Open the vscode workspaces associated with the installation.

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

Backup the installation, caprover, and postgres to the s3 bucket.

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

Restore the installation, caprover, and postgres from the s3 bucket.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--dir               - The directory of your SolOS project. (required on the first run)
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
--tag=<string>      - When supplied, we'll restore the latest backup that 
                      matches the tag. If no tag is supplied, we'll restore
                      the latest backup.
EOF
}
cli.usage.command.precheck.help() {
  cat <<EOF
Usage: solos precheck [--OPTS...]

Performs as many checks as possible on the solos runtime to ensure it will work
as expected.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--help              - Print this help and exit
EOF
}
cli.usage.command.gen.help() {
  cat <<EOF
Usage: solos gen [--OPTS...]

Generates source code, like __source__.sh files. Development only.

$LIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
