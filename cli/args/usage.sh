#!/usr/bin/env bash

vSELF_CLI_USAGE_CMD_HEADER="COMMANDS:"
vSELF_CLI_USAGE_OPTS_HEADER="OPTIONS:"
vSELF_CLI_USAGE_ALLOWS_CMDS=()
vSELF_CLI_USAGE_ALLOWS_OPTIONS=()

cli.usage.help() {
  cat <<EOF
USAGE: solos <command> <args..> [--OPTS...]

DESCRIPTION:

A CLI to manage SolOS projects on your local machine or container.

${vSELF_CLI_USAGE_CMD_HEADER}

checkout                 - Switch to a pre-existing project or initialize a new one.
app                      - Initializes or checks out a project app.
provision                - Provision resources for a project (eg. storage, databases, cloud instances, etc).
try                      - (DEV ONLY) Undocumented.

${vSELF_CLI_USAGE_OPTS_HEADER}

--assume-yes        - Assume yes for all prompts.

Source: https://github.com/InterBolt/solos
EOF
}
cli.usage.command.checkout.help() {
  cat <<EOF
USAGE: solos checkout <project> [--OPTS...]

DESCRIPTION:

Creates a new project if one doesn't exist and then switches to it. The project name \
is cached in the CLI so that all future commands operate against it. Think git checkout.

EOF
}
cli.usage.command.app.help() {
  cat <<EOF
USAGE: solos app <app-name> [--OPTS...]

DESCRIPTION:

Initialize a new app within a project if the app doesn't already exist. If it does, \
it will checkout and re-install env dependencies for the app.

EOF
}
cli.usage.command.provision.help() {
  cat <<EOF
USAGE: solos provision [--OPTS...]

DESCRIPTION:

Creates the required S3 buckets against your preferred S3-compatible object store.

EOF
}
cli.usage.command.try.help() {
  cat <<EOF
USAGE: solos try [--OPTS...]

DESCRIPTION:

Undocumented.

EOF
}
