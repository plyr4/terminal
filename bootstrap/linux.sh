#!/usr/bin/env bash
# linux prerequisites for debian/ubuntu style distributions.
# isolated from the macos path; keeps only what remains practical.
set -euo pipefail

go_version="${GO_VERSION:-1.22.5}"

echo "updating apt"
sudo apt-get update

echo "installing base apt packages"
sudo apt-get install -y \
  build-essential \
  ca-certificates \
  colordiff \
  curl \
  git \
  git-lfs \
  gnupg \
  jq \
  lsb-release \
  ripgrep \
  stow \
  tmux \
  tree \
  vim \
  xclip

# install go from the official tarball when missing or out of date
if ! command -v go >/dev/null 2>&1 || [ "$(go version | awk '{print $3}')" != "go${go_version}" ]; then
  echo "installing go ${go_version}"
  tmp="$(mktemp -d)"
  curl -fsSL "https://go.dev/dl/go${go_version}.linux-amd64.tar.gz" -o "$tmp/go.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$tmp/go.tar.gz"
  rm -rf "$tmp"
fi

# install docker engine via the official convenience script
if ! command -v docker >/dev/null 2>&1; then
  echo "installing docker"
  curl -fsSL https://get.docker.com | sh
fi

echo "linux bootstrap complete"
