#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o errtrace

cd "$(dirname "${BASH_SOURCE[0]}")"
viREPO_BIN_EXECUTABLE_PATH="bin/solos.sh"
#
# Important: please use "vi" prefix to avoid conflicts with other scripts
# we source remotely.
# Note: stands for "v" variable and "i" install.
#
viTMP_DIR="$(mktemp -d 2>/dev/null)"
viMY_TMP_CONFIG_BIN_DIR="$(mktemp -d 2>/dev/null)"
i.cleanup() {
  rm -rf "$viTMP_DIR"
  rm -rf "$viMY_TMP_CONFIG_BIN_DIR"
}
trap "i.cleanup" EXIT
viTMP_REPO="${viTMP_DIR}/solos"
viREPO_URL="https://github.com/InterBolt/solos.git"

git clone "${viREPO_URL}" "${viTMP_REPO}" &>/dev/null
if [ ! -f "${viTMP_REPO}/${viREPO_BIN_EXECUTABLE_PATH}" ]; then
  echo "${viTMP_REPO}/${viREPO_BIN_EXECUTABLE_PATH} not found. Exiting." >&2
  exit 1
fi
#
# Important: the remainder of the script assumes we're in the bin folder.
#
cd "${viTMP_REPO}/bin"
#
# Source anything we need an make sure the user has a
# config dir in the home folder.
#
# shellcheck source=bin/shared/static.sh
. "shared/static.sh"
# shellcheck source=bin/pkg/gum.sh
. "pkg/gum.sh"

#
# Fundamentally, we must clone the repo before we can source the static.sh file.
#
#
if [ "${viREPO_URL}" != "${vSTATIC_REPO_URL}" ]; then
  echo "repo url mismatch: ${viREPO_URL} != ${vSTATIC_REPO_URL}" >&2
  exit 1
fi

mkdir -p "$vSTATIC_MY_CONFIG_ROOT"
# shellcheck source=bin/shared/log.sh
. "shared/log.sh"
log.ready "install" "${vSTATIC_MY_CONFIG_ROOT}/${vSTATIC_LOGS_DIRNAME}"

do_install() {
  echo "Installing SolOS..."
  sleep 2
  #
  # Will download the bin script + all lib scripts to the user's local
  # solos config folder at config/bin/.
  # Then, the main executable at the user's path can call the main script as a command.
  #
  viUSR_LOCAL_BIN_EXECUTABLE="/usr/local/bin/solos"
  viBIN_SCRIPT_COMMENT_TAG="# from:solos"

  #
  # Overwrite the bin files stored in the config folder.
  #
  rm -rf "${vSTATIC_MY_CONFIG_ROOT:?}/bin"
  mkdir -p "${vSTATIC_MY_CONFIG_ROOT:?}/bin"
  cp -r "${viTMP_REPO}/bin/." "${vSTATIC_MY_CONFIG_ROOT:?}/bin"

  #
  # For extra safety, we'll see if the script looks like something we've installed before
  # based on the second line of the script, which is a distinct comment.
  # If it does, we're safe to overwrite it.
  #
  if [ -f "$viUSR_LOCAL_BIN_EXECUTABLE" ]; then
    if [ "$(sed -n '2p' "$viUSR_LOCAL_BIN_EXECUTABLE")" == "$viBIN_SCRIPT_COMMENT_TAG" ]; then
      log.warn "overwriting $viUSR_LOCAL_BIN_EXECUTABLE"
      rm -f "$viUSR_LOCAL_BIN_EXECUTABLE"
    else
      log.error "line: \`$viBIN_SCRIPT_COMMENT_TAG\` was not found in $viUSR_LOCAL_BIN_EXECUTABLE."
      log.error "can't verify that it was installed by solos."
      exit 1
    fi
  fi

  #
  # The actual bin script will live in the .solos folder for max portability.
  # This way when restoring on old system, the script will still work without needing
  # to be reinstalled or finding the original script version.
  #
  {
    echo "#!/usr/bin/env bash"
    echo "$viBIN_SCRIPT_COMMENT_TAG"
    echo "# This script was generated by the SolOS install at $(date)."
    echo ""
    echo "\"${vSTATIC_MY_CONFIG_ROOT:?}/$viREPO_BIN_EXECUTABLE_PATH\" \"\$@\""
  } >>"$viUSR_LOCAL_BIN_EXECUTABLE"
  chmod +x "$viUSR_LOCAL_BIN_EXECUTABLE"
}

pkg.gum.spinner "Installing SolOS..." "do_install"
log.info "success: solos installed at: ${vSTATIC_MY_CONFIG_ROOT:?}/$viREPO_BIN_EXECUTABLE_PATH"
log.info "run 'solos --help' to get started."