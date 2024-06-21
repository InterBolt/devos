#!/usr/bin/env bash

# Make sure the user has what they need on their host system before installing SolOS.
if ! command -v git >/dev/null; then
  echo "Host error [installer]: git is required to install SolOS. Please install it and try again." >&2
  exit 1
fi
if ! command -v bash >/dev/null; then
  echo "Host error [installer]: bash is required to install SolOS. Please install it and try again." >&2
  exit 1
fi
if ! command -v docker >/dev/null; then
  echo "Host error [installer]: docker is required to install SolOS. Please install it and try again." >&2
  exit 1
fi
if ! command -v code >/dev/null; then
  echo "Host error [installer]: VS Code is required to install SolOS. Please install it and try again." >&2
  exit 1
fi

SOURCE_MIGRATIONS_DIR="${HOME}/.solos/src/migrations"
USR_BIN_FILE="/usr/local/bin/solos"
SOURCE_BIN_FILE="${HOME}/.solos/src/bin/host.sh"
ORIGIN_REPO="https://github.com/InterBolt/solos.git"
SOURCE_REPO="${ORIGIN_REPO}"
TMP_DIR="$(mktemp -d 2>/dev/null)"
SOLOS_DIR="${HOME}/.solos"
DEV_MODE=false
DEV_MODE_SETUP_SCRIPT="${SOLOS_DIR}/src/dev/scripts/dev-mode-setup.sh"
SOLOS_SOURCE_DIR="${SOLOS_DIR}/src"

# Allow some of the variables to be overridden based on the command line arguments.
while [[ $# -gt 0 ]]; do
  case "${1}" in
  --dev)
    DEV_MODE=true
    shift
    ;;
  --repo=*)
    SOURCE_REPO="${1#*=}"
    if [[ ! ${SOURCE_REPO} =~ ^http ]]; then
      if [[ ! -d ${SOURCE_REPO} ]]; then
        echo "Host error [installer]: the specified repository does not exist: --repo=\"${SOURCE_REPO}\"" >&2
        exit 1
      fi
    fi
    shift
    ;;
  *)
    echo "Host error [installer]: unknown arg ${1}" >&2
    exit 1
    ;;
  esac
done

# Create the ~/.solos directory where everything will live.
if [[ ! -d ${SOLOS_DIR} ]]; then
  if ! mkdir -p "${SOLOS_DIR}"; then
    echo "Host error [installer]: failed to create ${SOLOS_DIR}" >&2
    exit 1
  fi
fi

# Attempt a git pull if .solos/src already exists and then exit if it fails.
# This seems like a reasonable default behavior that will prevent important unstaged
# changes from being overwritten.
if [[ -d ${SOLOS_SOURCE_DIR} ]]; then
  if ! git -C "${SOLOS_SOURCE_DIR}" pull >/dev/null 2>&1; then
    echo "Host error [installer]: failed to do a \`git pull\` in ${SOLOS_SOURCE_DIR}" >&2
    exit 1
  fi
fi

# Either clone the source repo or copy it from the specified directory.
# Prefer copying for local repos because it's more intuitive to include unstaged changes.
if ! mkdir -p "${SOLOS_SOURCE_DIR}"; then
  echo "Host error [installer]: failed to create ${SOLOS_SOURCE_DIR}" >&2
  exit 1
elif [[ -d ${SOURCE_REPO} ]]; then 
  cp -r "${SOURCE_REPO}/." "${SOLOS_SOURCE_DIR}/"
elif ! git clone "${SOURCE_REPO}" "${TMP_DIR}/src" >/dev/null; then
  echo "Host error [installer]: failed to clone ${SOURCE_REPO} to ${TMP_DIR}/src" >&2
  exit 1
elif ! git -C "${TMP_DIR}/src" remote set-url origin "${ORIGIN_REPO}"; then
  echo "Host error [installer]: failed to set the origin to ${ORIGIN_REPO}" >&2
  exit 1
elif ! cp -r "${TMP_DIR}/src/." "${SOLOS_SOURCE_DIR}/" >/dev/null 2>&1; then
  echo "Host error [installer]: failed to copy ${TMP_DIR}/src to ${SOLOS_SOURCE_DIR}" >&2
  exit 1
fi
echo "Host [installer]: prepared the SolOS source code at ${SOLOS_SOURCE_DIR}" >&2

# Make everything executable.
find "${SOLOS_SOURCE_DIR}" -type f -exec chmod +x {} \;

# Run migrations so that this script can handle installations and updates.
for migration_file in "${SOURCE_MIGRATIONS_DIR}"/*; do
  if ! "${migration_file}"; then
    echo "Host error [installer]: migration failed: ${migration_file}" >&2
    exit 1
  fi
done

if ! chmod +x "${SOURCE_BIN_FILE}"; then
  echo "Host error [installer]: failed to make ${USR_BIN_FILE} executable." >&2
  exit 1
fi
echo "Host [installer]: made ${SOURCE_BIN_FILE} executable." >&2
rm -f "${USR_BIN_FILE}"
if ! ln -sfv "${SOURCE_BIN_FILE}" "${USR_BIN_FILE}" >/dev/null; then
  echo "Host error [installer]: failed to symlink the host bin script." >&2
  exit 1
fi
echo "Host [installer]: symlinked ${USR_BIN_FILE} to ${SOURCE_BIN_FILE}" >&2
if ! chmod +x "${USR_BIN_FILE}"; then
  echo "Host error [installer]: failed to make ${USR_BIN_FILE} executable." >&2
  exit 1
fi
echo "Host [installer]: made ${USR_BIN_FILE} executable." >&2

# Run the dev mode setup script, which will add some reasonable starter folders, files, and scripts.
if [[ ${DEV_MODE} = true ]]; then
  echo "Host [installer]: (DEV_MODE=ON) - seeding the \$HOME/.solos directory." >&2
  export SUPPRESS_DOCKER_OUTPUT=false
  if ! "${DEV_MODE_SETUP_SCRIPT}" >/dev/null; then
    echo "Host error [installer]: failed to run SolOS dev-mode setup script." >&2
    exit 1
  else 
    echo "Host [installer]: ran the SolOS dev-mode setup script." >&2
  fi
else
  echo "Host [installer]: (DEV_MODE=OFF) - setting up a non-dev installation." >&2
  export SUPPRESS_DOCKER_OUTPUT=true
fi
# Confirms that the symlink worked AND that our container will build, run, and accept commands.
if ! solos --noop; then
  echo "Host error [installer]: failed to run SolOS cli after installing it." >&2
  exit 1
fi
cat <<EOF

$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)

SolOS has been successfully installed! Type \`solos --help\` to get started.

Source code: ${ORIGIN_REPO}
Documentation: https://[TODO]
Contact email: cc13.engineering@gmail.com
Twitter: https://twitter.com/interbolt_colin

$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -)

EOF
