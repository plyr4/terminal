#!/usr/bin/env bash
# macos prerequisites: xcode command line tools, Homebrew, and Brewfile packages.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# install the xcode command line tools if they are missing
if ! xcode-select -p >/dev/null 2>&1; then
  echo "installing xcode command line tools"
  xcode-select --install
  echo "re-run this script once the xcode tools have finished installing"
  exit 0
fi

# install Homebrew if it is missing
if ! command -v brew >/dev/null 2>&1; then
  echo "installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# make brew available in this shell (apple silicon or intel)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "updating Homebrew and installing packages from Brewfile"
brew update
brew bundle --file="$repo_root/Brewfile"

echo "macos bootstrap complete"
