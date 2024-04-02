#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

rm -rf /root/.bashrc
touch /root/.bashrc
source /root/.bashrc

# Ensures the script can be run from anywhere
cd "$(dirname "${BASH_SOURCE[0]}")"

env_path="/root/.env"
source_repo="InterBolt/devos"
clone_dir=/root/devos

if [ ! -f "$env_path" ]; then
  echo "$env_path does not exist. Exiting."
  exit 1
fi

# shellcheck disable=SC2046
export $(grep -v '^#' "$env_path" | sed 's/^/secret_/' | xargs)
if [ -z "$secret_github_token" ] || [ -z "$secret_github_email" ] || [ -z "$secret_github_email" ]; then
  echo "secret_github_token, secret_github_email, and secret_github_email must be set in $env_path"
  exit 1
fi

# Establish which environment we're in
if [ -f /.dockerenv ]; then
  host="local"
else
  host="remote"
fi

# Install Git
mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null
apt update

# Setup the github account and repo
apt install gh -y
echo "$secret_github_token" >/root/.tmp_github_token
gh auth login --git-protocol https --hostname github.com --with-token </root/.tmp_github_token
rm -f /root/.tmp_github_token
git config --global user.email "$secret_github_email"
git config --global user.name "$secret_github_email"
if [ -d "$clone_dir" ]; then
  mv "$clone_dir" "/root/.archive.$(date +%s)"
fi
gh repo clone "$source_repo" "$clone_dir"
cd "$clone_dir"
git submodule update --init --recursive

# Make the things executable
find . -type f -name "*.sh" -exec chmod +x {} \;

# Scripts will use this file to determine the host
echo "$host" >"$clone_dir"/config/.host

for var in $(compgen -A variable | grep "^secret_"); do
  # shellcheck disable=SC2001
  name="$(echo "$var" | sed -e "s/^secret_//")"
  echo "${!var}" >"$clone_dir"/.secrets/"$name"
done

# .secrets probably already exists, but why not a little future proofing.
mkdir -p "$clone_dir"/.secrets

# Provides the working dir assumption for the the installer's start scripts
cd "$clone_dir"
# Run the start script associated with the host
source installer/start/"$host".sh
