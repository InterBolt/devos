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

host="$1"
if [ -z "$host" ]; then
  echo "You must provide a host argument. Exiting."
  exit 1
fi
if [ "$host" != "docker" ] && [ "$host" != "remote" ]; then
  echo "The host argument must be either 'docker' or 'remote'. Exiting."
  exit 1
fi
# Establish which environment we're in
if [ "$host" == "docker" ]; then
  env_path="/root/workspace/.env"
  env_sh_path="/root/workspace/.env.sh"
else
  env_path="/root/.env"
  env_sh_path="/root/.env.sh"
fi

source_repo="InterBolt/devos"
clone_dir=/root/devos

if [ ! -f "$env_path" ]; then
  echo "$env_path does not exist. Exiting."
  exit 1
fi

# shellcheck disable=SC2046
export $(grep -v '^#' "$env_path" | sed 's/^/ENV_/' | xargs)
if [ -z "$ENV_GITHUB_TOKEN" ] || [ -z "$ENV_GITHUB_EMAIL" ] || [ -z "$ENV_GITHUB_EMAIL" ]; then
  echo "ENV_GITHUB_TOKEN, ENV_GITHUB_EMAIL, and ENV_GITHUB_EMAIL must be set in $env_path"
  exit 1
fi

# Install Git
mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null
apt update

# Setup the github account and repo
apt install gh -y
echo "$ENV_GITHUB_TOKEN" >/root/.tmp_github_token
gh auth login --git-protocol https --hostname github.com --with-token </root/.tmp_github_token
rm -f /root/.tmp_github_token
git config --global user.email "$ENV_GITHUB_EMAIL"
git config --global user.name "$ENV_GITHUB_EMAIL"
if [ ! -d "$clone_dir" ]; then
  gh repo clone "$source_repo" "$clone_dir"
fi
cd "$clone_dir"
git submodule update --init --recursive

# Make the things executable
find . -type f -name "*.sh" -exec chmod +x {} \;

cp -a "$env_path" "$clone_dir/.env"
cp -a "$env_sh_path" "$clone_dir/.env.sh"

# Run the start script associated with the host
# shellcheck disable=SC1090
source installer/start/"$host".sh
