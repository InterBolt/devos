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
teardown                 - Teardown provisioned resources.
backup                   - Backup all the things to an rsync target.
restore                  - Restore all the things from an rsync target.
health                   - Review health/status of provisioned resources.
test                     - (DEV ONLY) Undocumented.
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
cli.usage.command.test.help() {
  cat <<EOF
USAGE: solos test [--OPTS...]

DESCRIPTION:

Undocumented.

${vSELF_CLI_USAGE_OPTS_HEADER}

--lib               - (ex: "ssh" tests "lib.ssh") The name of the library to test.
--fn                - (ex: "lib.<category>.<fn>") The name of the lib function to test.

EOF
}
cli.usage.command.provision.help() {
  cat <<EOF
USAGE: solos provision [--OPTS...]

DESCRIPTION:

Initializes a new project and prepares the remote server for deployment. When this \
is run on a pre-existing project, it will try to init or update whatever the remote \
deployment server specified in the project's config.

EOF
}
cli.usage.command.teardown.help() {
  cat <<EOF
USAGE: solos teardown [--OPTS...]

DESCRIPTION:

Deprovision cloud resources.

EOF
}
cli.usage.command.backup.help() {
  cat <<EOF
USAGE: solos backup [--OPTS...]

DESCRIPTION:

Backup all the things and rysnc them to a target

EOF
}
cli.usage.command.restore.help() {
  cat <<EOF
USAGE: solos restore [--OPTS...]

DESCRIPTION:

Restore all the things from a remote rsync target.

EOF
}
cli.usage.command.health.help() {
  cat <<EOF
USAGE: solos health [--OPTS...]

DESCRIPTION:

Review health/status of provisioned resources.

EOF
}
cli.usage.command.try.help() {
  cat <<EOF
USAGE: solos try [--OPTS...]

DESCRIPTION:

Undocumented.

EOF
}
