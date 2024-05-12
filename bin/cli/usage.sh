#!/usr/bin/env bash

vSELF_CLI_USAGE_CMD_HEADER="Available commands:"
vSELF_CLI_USAGE_OPTS_HEADER="Available options:"
vSELF_CLI_USAGE_ALLOWS_CMDS=()
vSELF_CLI_USAGE_ALLOWS_OPTIONS=()

cli.usage.help() {
  cat <<EOF
Usage: solos command [--OPTS...]

A CLI to manage SolOS projects on your local machine or container.

${vSELF_CLI_USAGE_CMD_HEADER}

checkout                 - Switch to a pre-existing project or initialize a new one.
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
Usage: solos checkout [--OPTS...]

Creates a new project if one doesn't exist and then switches to it. The value 
provided to --project is cache and used as the default project for future commands.

${vSELF_CLI_USAGE_OPTS_HEADER}

--project           - The name of of your project. Will result in a new project at ~/.solos/projects/<project>.

EOF
}
cli.usage.command.test.help() {
  cat <<EOF
Usage: solos test [--OPTS...]

Undocumented.

${vSELF_CLI_USAGE_OPTS_HEADER}

--lib               - (ex: "ssh" tests "lib.ssh") The name of the library to test.
--fn                - (ex: "lib.<category>.<fn>") The name of the lib function to test.

EOF
}
cli.usage.command.provision.help() {
  cat <<EOF
Usage: solos provision [--OPTS...]

Initializes a new project and prepares the remote server for deployment. When this 
is run on a pre-existing project, it will try to init or update whatever the remote
deployment server specified in the project's config.

EOF
}
cli.usage.command.teardown.help() {
  cat <<EOF
Usage: solos teardown [--OPTS...]

Deprovision cloud resources.

EOF
}
cli.usage.command.backup.help() {
  cat <<EOF
Usage: solos backup [--OPTS...]

Backup all the things and rysnc them to a target

EOF
}
cli.usage.command.restore.help() {
  cat <<EOF
Usage: solos restore [--OPTS...]

Restore all the things from a remote rsync target.

EOF
}
cli.usage.command.health.help() {
  cat <<EOF
Usage: solos health [--OPTS...]

Review health/status of provisioned resources.

EOF
}
cli.usage.command.try.help() {
  cat <<EOF
Usage: solos try [--OPTS...]

Undocumented.

EOF
}
