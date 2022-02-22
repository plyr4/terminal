#!/bin/sh

# prompts
set -x

echo "running brew/mac_install.sh"

echo "installing xcode tools"

# install xcode tools
xcode-select --install

# install brew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

echo "running brew update"

# update brew
brew update

echo "installing default brew packages"

# install default brew packages
DEFAULT_BREW_PACKAGES=brew/packages
if test -f "$DEFAULT_BREW_PACKAGES"; then
    xargs brew install < $DEFAULT_BREW_PACKAGES
fi
