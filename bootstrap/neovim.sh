#!/usr/bin/env bash
# install the neovim config (plyr4 astronvim fork) into ~/.config/nvim.
# override the source with NVIM_CONFIG_REPO. safe to re-run.
set -euo pipefail

nvim_repo="${NVIM_CONFIG_REPO:-git@github.com:plyr4/AstroVim.git}"
nvim_dir="$HOME/.config/nvim"

# back up any existing non-git config so nothing is lost
if [ -e "$nvim_dir" ] && [ ! -d "$nvim_dir/.git" ]; then
  backup="${nvim_dir}.backup.$(date +%Y%m%d%H%M%S)"
  echo "backing up existing nvim config to $backup"
  mv "$nvim_dir" "$backup"
fi

if [ -d "$nvim_dir/.git" ]; then
  echo "nvim config already present, pulling latest"
  git -C "$nvim_dir" pull --ff-only
else
  echo "cloning $nvim_repo into $nvim_dir"
  git clone "$nvim_repo" "$nvim_dir"
fi

echo "done. launch nvim to install plugins (run ':Lazy sync' if it does not start automatically)"
