#!/usr/bin/env bash

export vSTATIC_HOST="machine"
if [[ -f /.dockerenv ]]; then
  export vSTATIC_HOST="docker"
fi
export vSTATIC_RUNNING_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
export vSTATIC_REPO_URL="https://github.com/InterBolt/solos.git"
export vSTATIC_SERVER_ROOT="/root"

export vSTATIC_SOLOS_DIRNAME=".solos"
export vSTATIC_SOLOS_ROOT="${HOME}/${vSTATIC_SOLOS_DIRNAME}"
export vSTATIC_SOLOS_PROJECTS_ROOT="${vSTATIC_SOLOS_ROOT}/projects"
export vSTATIC_SERVER_CLONE_DIR="${vSTATIC_SERVER_ROOT}/solos"
export vSTATIC_MANUAL_FILENAME="manual.txt"
export vSTATIC_SSH_CONF_DOCKER_HOSTNAME="solos-dev"
export vSTATIC_SSH_CONF_REMOTE_HOSTNAME="solos-remote"
export vSTATIC_LAUNCH_DIRNAME=".launch"
export vSTATIC_BIN_LAUNCH_DIR="bin/${vSTATIC_LAUNCH_DIRNAME}"
export vSTATIC_DOCKER_MOUNTED_LAUNCH_DIR="/root/project/${vSTATIC_LAUNCH_DIRNAME}"
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

export vSTATIC_LOGS_FILENAME="bin.log"
export vSTATIC_LOGS_DIR="${vSTATIC_SOLOS_ROOT}/${vSTATIC_LOGS_DIRNAME}"
export vSTATIC_LOG_FILEPATH="${vSTATIC_LOGS_DIR}/solos.log"
