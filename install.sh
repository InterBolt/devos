#!/usr/bin/env bash

SOURCE_BIN_FILE="${HOME}/.solos/src/host/bin.sh"
SOURCE_MIGRATIONS_DIR="${HOME}/.solos/src/migrations"
USR_BIN_FILE="/usr/local/bin/solos"
ORIGIN_REPO="https://github.com/InterBolt/solos.git"
REPO="${ORIGIN_REPO}"
TMP_DIR="$(mktemp -d 2>/dev/null)"
SOLOS_DIR="${HOME}/.solos"
DEV_MODE=false
DEV_MODE_SETUP_SCRIPT="${SOLOS_DIR}/src/dev/scripts/dev-mode-setup.sh"
SOLOS_SOURCE_DIR="${SOLOS_DIR}/src"
REPO_EXISTS_LOCALLY=true

# Allow some of the variables to be overridden based on the command line arguments.
while [[ $# -gt 0 ]]; do
  case "${1}" in
  --dev)
    DEV_MODE=true
    shift
    ;;
  --repo=*)
    REPO="${1#*=}"
    if [[ ! ${REPO} =~ ^http ]]; then
      if [[ ! -d ${REPO} ]]; then
        echo "The specified repository does not exist: ${REPO}" >&2
        exit 1
      fi
    fi
    shift
    ;;
  *)
    echo "Unknown argument: ${1}" >&2
    exit 1
    ;;
  esac
done

# Create the ~/.solos directory where everything will live.
if [[ ! -d ${SOLOS_DIR} ]]; then
  REPO_EXISTS_LOCALLY=false
  if ! mkdir -p "${SOLOS_DIR}"; then
    echo "Failed to create ${SOLOS_DIR}" >&2
    exit 1
  fi
# Attempt a git pull if .solos/src already exists and then exit if it fails.
# This seems like a reasonable default behavior that will prevent important unstaged
# changes from being overwritten.
elif [[ -d ${SOLOS_SOURCE_DIR} ]]; then
  if ! git -C "${SOLOS_SOURCE_DIR}" pull >/dev/null 2>&1; then
    echo "Failed to do a \`git pull\` in ${SOLOS_SOURCE_DIR}" >&2
    exit 1
  fi
else
  REPO_EXISTS_LOCALLY=false
fi

# If the repo wasn't found in ~/.solos/src, clone it from the specified remote.
if [[ ${REPO_EXISTS_LOCALLY} = false ]]; then
  echo "Cloning the SolOS repository to ${SOLOS_SOURCE_DIR}" >&2
  if ! git clone "${REPO}" "${TMP_DIR}/src" >/dev/null; then
    echo "Failed to clone ${REPO} to ${TMP_DIR}/src" >&2
    exit 1
  fi
  echo "Cloned the SolOS repository to ${TMP_DIR}/src" >&2
  if ! git -C "${TMP_DIR}/src" remote set-url origin "${ORIGIN_REPO}"; then
    echo "Failed to set the origin to ${ORIGIN_REPO}" >&2
    exit 1
  fi
  echo "Ensured the correct origin repo: ${ORIGIN_REPO}." >&2
  if ! mkdir -p "${SOLOS_SOURCE_DIR}"; then
    echo "Failed to create ${SOLOS_SOURCE_DIR}" >&2
    exit 1
  fi
  echo "Initialized the ${SOLOS_SOURCE_DIR} directory." >&2
  if ! cp -r "${TMP_DIR}/src/." "${SOLOS_SOURCE_DIR}" >/dev/null 2>&1; then
    echo "Failed to copy ${TMP_DIR}/src to ${SOLOS_SOURCE_DIR}" >&2
    exit 1
  fi
  echo "Copied the contents of ${TMP_DIR}/src to ${SOLOS_SOURCE_DIR}" >&2
else
  echo "Found and pulled latest changes to the SolOS repository in ${SOLOS_SOURCE_DIR}" >&2
fi

# Make everything executable.
find "${SOLOS_SOURCE_DIR}" -type f -exec chmod +x {} \;

# Run migrations so that this script can handle installations and updates.
for migration_file in "${SOURCE_MIGRATIONS_DIR}"/*; do
  if ! "${migration_file}"; then
    echo "Migration failed: ${migration_file}" >&2
    exit 1
  fi
done

# Symlink the bin script in the host directory to /usr/local/bin/solos.
if ! ln -sfv "${SOURCE_BIN_FILE}" "${USR_BIN_FILE}" >/dev/null; then
  echo "Failed to link ${SOURCE_BIN_FILE} to ${USR_BIN_FILE}" >&2
  exit 1
fi

# Make sure the symlink is executable.
if ! chmod +x "${USR_BIN_FILE}"; then
  echo "Failed to make ${USR_BIN_FILE} executable." >&2
  exit 1
fi

# Run the dev mode setup script, which will add some reasonable starter folders, files, and scripts.
if [[ ${DEV_MODE} = true ]]; then
  echo "(DEV_MODE=ON) - setting up a dev-friendly \$HOME/.solos directory." >&2
  if ! "${DEV_MODE_SETUP_SCRIPT}" >/dev/null; then
    echo "SolOS installation failed." >&2
    echo "Failed to run SolOS dev-mode setup script." >&2
    return 1
  fi
else
  echo "(DEV_MODE=OFF) - setting up a non-dev installation." >&2
fi

# Confirms that the symlink worked AND that our container will build, run, and accept commands.
if ! solos --noop; then
  echo "SolOS installation failed." >&2
  echo "Failed to run SolOS cli after installing it." >&2
  return 1
fi
