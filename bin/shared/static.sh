#!/usr/bin/env bash

export vMODE="${MODE:-"production"}"
export vSTATIC_HOST=""
if [ "$(uname)" == "Darwin" ]; then
  export vSTATIC_HOST="local"
elif [ -f /.dockerenv ]; then
  export vSTATIC_HOST="docker"
else
  export vSTATIC_HOST="remote"
fi
export vSTATIC_RUNNING_REPO_ROOT=""
if [ -z "$(git rev-parse --show-toplevel 2>/dev/null)" ]; then
  export vSTATIC_RUNNING_IN_GIT_REPO=false
  export vSTATIC_RUNNING_REPO_ROOT=""
else
  export vSTATIC_RUNNING_IN_GIT_REPO=true
  export vSTATIC_RUNNING_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
fi
export vSTATIC_REPO_URL="https://github.com/InterBolt/solos.git"
export vSTATIC_LOGS_FILENAME="bin.log"
export vSTATIC_LOG_FILEPATH=""
if [ -d "${vSTATIC_MY_CONFIG_ROOT}" ]; then
  vSTATIC_LOG_FILEPATH="${vSTATIC_MY_CONFIG_ROOT}/${vSTATIC_LOGS_DIRNAME}/${vSTATIC_LOGS_FILENAME}"
elif [ -n "${vSTATIC_RUNNING_REPO_ROOT}" ]; then
  vSTATIC_LOG_FILEPATH="${vSTATIC_RUNNING_REPO_ROOT}/${vSTATIC_LOGS_DIRNAME}/${vSTATIC_LOGS_FILENAME}"
else
  vSTATIC_LOG_FILEPATH="${PWD}/${vSTATIC_LOGS_DIRNAME}/${vSTATIC_LOGS_FILENAME}"
fi
mkdir -p "$(dirname "${vSTATIC_LOG_FILEPATH}")"
if [ ! -f "${vSTATIC_LOG_FILEPATH}" ]; then
  touch "${vSTATIC_LOG_FILEPATH}"
fi
#
# TODO: is there an automated way to scan our code and get a list of
# TODO[c]: all the commands we assume the user has installed.
#
export vSTATIC_DEPENDENCY_COMMANDS=(
  "curl"
  "jq"
  "openssl"
  "git"
  "rsync"
  "docker"
  "aws"
)
export vSTATIC_SERVER_ROOT="/root"
#
# Important: don't get fancy and rename the config on the remote.
# It sucks to see .solos and solos both in the vscode file directory
# but it's worth the benefits of having a consistent config directory.
# Lots of tiny bugs start to happen if we can't blindly assume a consistent
# config dir name.
#
export vSTATIC_CONFIG_DIRNAME=".solos"
export vSTATIC_MY_CONFIG_ROOT="$HOME/${vSTATIC_CONFIG_DIRNAME}"
export vSTATIC_SERVER_CONFIG_ROOT="${vSTATIC_SERVER_ROOT}/${vSTATIC_CONFIG_DIRNAME}"
export vSTATIC_SERVER_CLONE_DIR="${vSTATIC_SERVER_ROOT}/solos"
export vSTATIC_MANUAL_FILENAME="manual.txt"
export vSTATIC_SSH_CONF_DOCKER_HOSTNAME="solos-dev"
export vSTATIC_SSH_CONF_REMOTE_HOSTNAME="solos-remote"
export vSTATIC_LAUNCH_DIRNAME=".launch"
export vSTATIC_BIN_LAUNCH_DIR="bin/$vSTATIC_LAUNCH_DIRNAME"
export vSTATIC_DOCKER_MOUNTED_LAUNCH_DIR="/root/project/$vSTATIC_LAUNCH_DIRNAME"
export vSTATIC_REPO_SERVERS_DIR="servers"
export vSTATIC_LINUX_SH_FILENAME="linux.sh"
export vSTATIC_VULTR_INSTANCE_DEFAULTS=(
  "voc-c-2c-4gb-50s-amd"
  "ewr"
  2136
)
export vSTATIC_SERVER_BOOTFILES=(
  "remote.sh"  # preps the deployment server
  "docker.sh"  # preps the dev docker container
  "Dockerfile" # define our dev container
)
export vSTATIC_TEMPLATE_BOOTFILES=(
  "compose.yml"           # defined dev container
  "docker.code-workspace" # loads SSH remote to dev container
  "remote.code-workspace" # loads SSH remote to deployment server
)
export vSTATIC_ENV_FILENAME=".env"
export vSTATIC_ENV_SH_FILENAME=".env.sh"
export vSTATIC_LOGS_DIRNAME=".logs"
export vSTATIC_SSH_RSA_KEYNAME="lib.rsa"
export vSTATIC_SSH_PUB_KEYNAME="lib.pub"
export vSTATIC_SSH_AUTHORIZED_KEYS_FILENAME="authorized_keys"
export vSTATIC_SSH_CONFIG_FILENAME="solos_config"
export vSTATIC_DB_ONE_CLICK_TEMPLATE_FILENAME=".secret.database.json"
export vSTATIC_USR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
export vSTATIC_SOLOS_ID_FILENAME=".solos_id"
export vSTATIC_SERVER_TYPE_FILENAME=".solos_server_type"
export vSTATIC_DEFAULT_SERVER="debian12personal"
