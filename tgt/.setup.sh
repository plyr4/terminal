#!/bin/sh

# prompts
set -x

echo "running tgt/setup.sh"

echo "installing brew packages"

# brew packages
brew install colima vault vela

echo "done! open AstroVim with 'nvim' and run ':PackerSync' ':TSInstall' and 'LspInstall'"
