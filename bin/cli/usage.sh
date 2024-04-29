#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

vSELF_CLI_USAGE_CMD_HEADER="Available commands:"
vSELF_CLI_USAGE_OPTS_HEADER="Available options:"
vSELF_CLI_USAGE_ALLOWS_CMDS=()
vSELF_CLI_USAGE_ALLOWS_OPTIONS=()

cli.usage.help() {
  cat <<EOF
Usage: solos command [--OPTS...]

A CLI to manage SolOS projects on your local machine or container.

$vSELF_CLI_USAGE_CMD_HEADER

checkout                 - Switch to a pre-existing project or initialize a new one.
provision                - Provision resources for a project (eg. storage, databases, cloud instances, etc).
teardown                 - Teardown provisioned resources.
backup                   - Backup all the things to an rsync target.
restore                  - Restore all the things from an rsync target.
health                   - Review health/status of provisioned resources.
dev                      - Launches a VSCode workspace for a project.
test                     - (DEV ONLY) Generates and runs unit tests. 
try                      - (DEV ONLY) one off entrypoint to test snippets in the command portion of the 
                           SolOS bin script.

$vSELF_CLI_USAGE_OPTS_HEADER

--output                 - (default: background) When set to plain, logs will display in a cumulative way. 
                           When set to background, a spinner is shown and only the last log will display.
--assume-yes             - Assume yes for all prompts

Source: https://github.com/InterBolt/solos
EOF
}
cli.usage.command.checkout.help() {
  cat <<EOF
Usage: solos checkout [--OPTS...]

Creates a new project if one doesn't exist and then switches to it. The value 
provided to --project is cache and used as the default project for future commands.

$vSELF_CLI_USAGE_OPTS_HEADER

--project           - The name of of your project. Will result in a new project at ~/.solos/projects/<project>.
--output            - (default: background) When set to plain, logs will display in a cumulative way.  
                      When set to background, a spinner is shown and only the last log will display.
--assume-yes        - Assume yes for all prompts

EOF
}
cli.usage.command.test.help() {
  cat <<EOF
Usage: solos test [--OPTS...]

DEV ONLY! Runs tests from within the SolOS source repository.

$vSELF_CLI_USAGE_OPTS_HEADER

--lib               - (ex: "ssh" tests "lib.ssh") The name of the library to test.
--fn                - (ex: "lib.<category>.<fn>") The name of the lib function to test.
--output            - (default: background) When set to plain, logs will display in a cumulative way.  
                      When set to background, a spinner is shown and only the last log will display.
--assume-yes        - Assume yes for all prompts

EOF
}
cli.usage.command.dev.help() {
  cat <<EOF
Usage: solos dev [--OPTS...]

Builds and runs a development docker container and opens a connected
VSCode workspace.

$vSELF_CLI_USAGE_OPTS_HEADER

--project           - (default: <cache>) The project name of of your project.
--output            - (default: background) When set to plain, logs will display in a cumulative way. 
                      When set to background, a spinner is shown and only the last log will display.
EOF
}
cli.usage.command.provision.help() {
  cat <<EOF
Usage: solos provision [--OPTS...]

Initializes a new project and prepares the remote server for deployment. When this 
is run on a pre-existing project, it will try to init or update whatever the remote
deployment server specified in the project's config.

$vSELF_CLI_USAGE_OPTS_HEADER

--project           - (default: <cache>) The name of of your project.
--output            - (default: background) When set to plain, logs will display in a cumulative way. 
                      When set to background, a spinner is shown and only the last log will display.
EOF
}
cli.usage.command.teardown.help() {
  cat <<EOF
Usage: solos teardown [--OPTS...]

Deprovision cloud resources.

$vSELF_CLI_USAGE_OPTS_HEADER

--project           - (default: <cache>) The name of of your project.
--output            - (default: background) When set to plain, logs will display in a cumulative way. 
                      When set to background, a spinner is shown and only the last log will display.
EOF
}
cli.usage.command.backup.help() {
  cat <<EOF
Usage: solos backup [--OPTS...]

Backup all the things and rysnc them to a target

$vSELF_CLI_USAGE_OPTS_HEADER

--target            - The target to rsync to in format (\`user@host:/path/to/backup\`).
--project           - (default: <cache>) The name of of your project.
--output            - (default: background) When set to plain, logs will display in a cumulative way. 
                      When set to background, a spinner is shown and only the last log will display.
EOF
}
cli.usage.command.restore.help() {
  cat <<EOF
Usage: solos restore [--OPTS...]

Restore all the things from a remote rsync target.

$vSELF_CLI_USAGE_OPTS_HEADER

--source            - The source to rsync from in format (\`user@host:/path/to/restore\`).
--project           - (default: <cache>) The name of of your project.
--output            - (default: background) When set to plain, logs will display in a cumulative way. 
                      When set to background, a spinner is shown and only the last log will display.
EOF
}
cli.usage.command.health.help() {
  cat <<EOF
Usage: solos health [--OPTS...]

Review health/status of provisioned resources.

$vSELF_CLI_USAGE_OPTS_HEADER

--project           - (default: <cached>) The name of of your project.
--output            - (default: background) When set to plain, logs will display in a cumulative way. 
                      When set to background, a spinner is shown and only the last log will display.
EOF
}
cli.usage.command.try.help() {
  cat <<EOF
Usage: solos try [--OPTS...]

Nothing to see here.

$vSELF_CLI_USAGE_OPTS_HEADER

--project           - (default: <cached>) The name of of your project.
--output            - (default: background) When set to plain, logs will display in a cumulative way.  
                      When set to background, a spinner is shown and only the last log will display.
--assume-yes        - Assume yes for all prompts

EOF
}
