#!/usr/bin/env bash

set -o nounset
set -o pipefail
set -o errtrace
#
# Note: I was noticing that the bashrc was failing to source the first
# time the script was run. I don't know why but the contents of the .bashrc
# didn't seem to mean anything so let's just start from scratch.
#
vBASHRC_FILEPATH="/root/.bashrc"
rm -f "${vBASHRC_FILEPATH}"
touch "${vBASHRC_FILEPATH}"
. "${vBASHRC_FILEPATH}"
cd "$(dirname "${BASH_SOURCE[0]}")"
#
# Important: please prefix with "v" to avoid collisions with
# the environment variables that are sourced from the .env file.
#
vCONFIG_DIR="/root/.solos"
vBIN_SCRIPT_FILEPATH="${vCONFIG_DIR}/bin/solos.sh"
vUSR_BIN_FILEPATH="/usr/local/bin/solos"
vGITHUB_REPO="InterBolt/solos"
vREMOTE_CLONE_DIR=/root/solos
vDOCKER_MOUNTED_REPO=/root/project/repo
vSERVER_DIR=""
vARG_HOST="$1"
vARG_SERVER="$2"
vARG_GITHUB_USERNAME="$3"
vARG_GITHUB_EMAIL="$4"
vARG_GITHUB_TOKEN="$5"
#
# Add a check since we can't get this directory from the static
# script. vCONFIG_DIR should be the .solos folder that we uploaded or mounted
# to the server from our local machine.
#
if [[ ! -d ${vCONFIG_DIR} ]]; then
  echo "${vCONFIG_DIR} does not exist. this must exist in all non-local environments." >&2
  exit 1
fi
if [[ -z ${vARG_HOST} ]]; then
  echo "No argument provided. Expected <host> <server>" >&2
  exit 1
fi
if [[ ${vARG_HOST} != "docker" ]] && [[ ${vARG_HOST} != "remote" ]]; then
  echo "<host> argument must be either 'docker' or 'remote'." >&2
  exit 1
fi
if [[ -z ${vARG_GITHUB_USERNAME} ]]; then
  echo "Expected the third argument to be the github username." >&2
  exit 1
fi
if [[ -z ${vARG_GITHUB_EMAIL} ]]; then
  echo "Expected the fourth argument to be the github email." >&2
  exit 1
fi
if [[ -z ${vARG_GITHUB_TOKEN} ]]; then
  echo "Expected the fifth argument to be the github token." >&2
  exit 1
fi
#
# Install Git
#
mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null
apt update
#
# Setup the github account and repo
#
apt install gh -y
mkdir -p /root/.tmp
echo "${vARG_GITHUB_TOKEN}" >/root/.tmp/github_token
gh auth login --git-protocol https --hostname github.com --with-token </root/.tmp/github_token
rm -f /root/.tmp/github_token
git config --global user.email "${vARG_GITHUB_EMAIL}"
git config --global user.name "${vARG_GITHUB_USERNAME}"
#
# Important: I'm deliberately allowing this on the remote because
# there's very little footprint for lots of upside when we're in a pinch.
# Also, I'm not bothering with aliasing the explain command because
# I don't use it much and in the rare case I can just type it out.
#
gh extension install --force github/gh-copilot >/dev/null
vSUGGEST_ALIAS="?"
if [[ "$(type -t "${vSUGGEST_ALIAS}")" != 'alias' ]]; then
  # shellcheck disable=SC2016
  {
    echo 'eval "$(gh copilot alias -- bash)"'
    echo 'alias "'"${vSUGGEST_ALIAS}"'"="ghcs -t shell"'
    echo 'alias "'"${vSUGGEST_ALIAS}"'"="ghcs -t shell"'
    echo 'alias ge="ghce -t shell"'
    echo 'alias gs="ghcs -t shell"'
  } >>"$vBASHRC_FILEPATH"
fi
#
# When running in docker, use the same repo we cloned locally
# and mounted to the container. When running on a remote server,
# clone the repo from github.
#
if [[ ${vARG_HOST} = "docker" ]]; then
  if [[ ! -d ${vDOCKER_MOUNTED_REPO} ]]; then
    echo "The mounted repo does not exist." >&2
    exit 1
  fi
  cd "${vDOCKER_MOUNTED_REPO}"
else
  if [[ ! -d ${vREMOTE_CLONE_DIR} ]]; then
    gh repo clone "${vGITHUB_REPO}" "${vREMOTE_CLONE_DIR}"
  fi
  cd "${vREMOTE_CLONE_DIR}"
fi
#
# Now check that the server type we want to install exists.
# Note: this check shouldn't really ever fail since we're
# checking it on the local machine before we kick this script
# off. HOWEVER, since we're not pulling the latest repo changes
# by default, there's a chance that the server type we want to
# install doesn't exist in the repo on the server.
#
vSERVER_DIR="servers/${vARG_SERVER}"
if [[ ! -d ${vSERVER_DIR} ]]; then
  echo "${vSERVER_DIR} does not exist!" >&2
  echo "The repo on this server must be out of sync with the local repo. Exiting." >&2
  exit 1
fi
#
# Make the things executable
#
find . -type f -name "*.sh" -exec chmod +x {} \;
#
# Run the remaining commands from within the boot folder
#
cd "${vSERVER_DIR}"/.launch
#
# Run the start script associated with the host
#
# shellcheck disable=SC1090
. "${vARG_HOST}".sh
#
# When invoking the `solos` cli, the remote will tell you not to
# and the docker container will invoke the script that is living in the
# mounted config directory. This is the `.solos` directory on your local
# machine.
#
# Important: Don't change to use the mounted repo's bin script.
# I'd rather they be in sync and out of date than out of sync
# and up to date. If we want to invoke the bin script in the repo
# we should, just like, do that manually.
#
if [[ -f ${vUSR_BIN_FILEPATH} ]]; then
  rm -f "${vUSR_BIN_FILEPATH}"
fi
if [[ ${vARG_HOST} = "docker" ]]; then
  {
    echo "#!/usr/bin/env bash"
    echo ""
    echo "# This script was generated by the solos installer at $(date)."
    echo ""
    echo "${vBIN_SCRIPT_FILEPATH} \"\$@\""
  } >>"${vUSR_BIN_FILEPATH}"
  chmod +x "${vBIN_SCRIPT_FILEPATH}"
  chmod +x "${vUSR_BIN_FILEPATH}"
else
  {
    echo "#!/usr/bin/env bash"
    echo ""
    echo "# This script was generated by the solos installer at $(date)."
    echo ""
    echo "echo \"This script is not meant to be run on a remote server.\" >&2"
    echo "exit 1"
  } >>"${vUSR_BIN_FILEPATH}"
  chmod +x "${vUSR_BIN_FILEPATH}"
fi
