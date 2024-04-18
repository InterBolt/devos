#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

vLIB_FLAGS_HEADER_AVAILABLE_COMMANDS="Available commands:"
vLIB_FLAGS_HEADER_AVAILABLE_OPTIONS="Available options:"

cli.usage.help() {
  cat <<EOF
Usage: solos command [--OPTS...]

A CLI to manage SolOS projects on your local machine or container.

$vLIB_FLAGS_HEADER_AVAILABLE_COMMANDS

help                     - Print this help and exit
create                   - Create a new SolOS project.
backup                   - Archive a SolOS project and upload it to an s3 bucket.
restore                  - Restore a SolOS project from an s3 bucket. It is optional to 
                           override the config on your working machine.
dev                      - Launch a docker container and connect to it with VSCode.
test                     - Generates and runs unit tests for each of Solos's lib.* 
                           libraries.

$vLIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--help                   - Print this help and exit
--foreground             - Avoids usage of the progress spinner and subshells so that logging happens in 
                           the foreground.

Source: https://github.com/InterBolt/solos
EOF
}
cli.usage.command.create.help() {
  cat <<EOF
Usage: solos create [--OPTS...]

Launches a new project and sets the active project directory so 
that subsequent commands will not need to specify the --project option.

$vLIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--project           - The project name of of your project.
--help              - Print this help and exit
--foreground        - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
cli.usage.command.test.help() {
  cat <<EOF
Usage: solos test [--OPTS...]

DEV ONLY! Runs tests from within the SolOS source repository.

$vLIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--lib               - (ex: "ssh" tests "lib.ssh") The name of the library to test.
--fn                - (ex: "lib.<category>.<fn>") The name of the lib function to test.
--help              - Print this help and exit
--foreground        - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
cli.usage.command.dev.help() {
  cat <<EOF
Usage: solos dev [--OPTS...]

Builds and runs a development docker container and opens a connected
VSCode workspace.

$vLIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--project           - The project name of of your project.
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
cli.usage.command.backup.help() {
  cat <<EOF
Usage: solos backup [--OPTS...]

Backup the project to an S3 compatible bucket.

$vLIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--project           - The project name of of your project.
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
cli.usage.command.restore.help() {
  cat <<EOF
Usage: solos restore [--OPTS...]

Restore the project from an S3 compatible bucket.

$vLIB_FLAGS_HEADER_AVAILABLE_OPTIONS

--project           - The project name of of your project.
--help              - Print this help and exit
--foreground         - Avoids usage of the progress spinner and subshells so that logging happens in 
                      the foreground.
EOF
}
