#!/bin/sh

# prompts
set -x

# install xcode tools
xcode-select --install

# install brew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# update brew
brew update

# install default brew packages
DEFAULT_BREW_PACKAGES=brew/packages
if test -f "$DEFAULT_BREW_PACKAGES"; then
    xargs brew install < $DEFAULT_BREW_PACKAGES
fi
