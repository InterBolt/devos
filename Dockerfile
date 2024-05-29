FROM debian:latest

SHELL ["/bin/bash", "-c"]

# TODO: research whether or not all of these packages are necessary
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes --no-install-recommends \
  git-all \
  coreutils \
  awscli \
  moreutils \
  rsync \
  bash-completion \
  ca-certificates \
  man-db \
  curl \
  jq \
  wget \
  sudo \
  build-essential \
  manpages-dev \
  procps \
  keychain

# Install GitHub CLI
RUN (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y

# Make logs pretty
ENV TERM=xterm-256color

# Docker - CLI only
RUN sudo apt-get remove docker.io \
  && sudo apt-get remove docker-doc \
  && sudo apt-get remove docker-compose \
  && sudo apt-get remove podman-docker \
  && sudo apt-get remove containerd \
  && sudo apt-get remove runc \
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/docker.asc \
  && echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list >/dev/null \
  && apt-get update \
  && apt-get install docker-ce-cli docker-buildx-plugin -y

CMD ["tail", "-f", "/dev/null"]