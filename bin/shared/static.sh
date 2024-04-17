#!/usr/bin/env bash

export vSTATIC_HOST="machine"
if [[ -f /.dockerenv ]]; then
  export vSTATIC_HOST="docker"
fi
export vSTATIC_SRC_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
export vSTATIC_GIT_REMOTE="https://github.com/InterBolt/solos.git"
export vSTATIC_SOLOS_ROOT="${HOME}/.solos"
export vSTATIC_SOLOS_PROJECTS_ROOT="${HOME}/.solos/projects"
export vSTATIC_SOLOS_ID_FILENAME=".solos_id"
export vSTATIC_LOGS_DIR="${vSTATIC_SOLOS_ROOT}/.logs"
export vSTATIC_LOG_FILEPATH="${vSTATIC_LOGS_DIR}/solos.log"
