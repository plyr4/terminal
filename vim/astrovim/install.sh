#!/bin/sh
set -x

echo "installing AstroVim, forked from plyr4"

# clone AstroVim
git clone git@github.com:plyr4/AstroVim.git /tmp/AstroVim

# remove nvim config
mv ~/.config/nvim ~/.config/nvim_backup

# install AstroVim
mv /tmp/AstroVim ~/.config/nvim

echo "done! open AstroVim with 'nvim' and run ':PackerSync' ':TSInstall' and 'LspInstall'"