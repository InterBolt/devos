#!/bin/bash

apt-get remove docker.io docker-doc docker-compose podman-docker containerd runc

# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    bookworm stable" |
  tee /etc/apt/sources.list.d/docker.list
apt-get update

apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
if ! docker run hello-world; then
  echo "Docker failed to run hello-world." >&2
  exit 1
fi
