#!/usr/bin/env bash
# symlink the stow packages into $HOME. safe to re-run.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stow_dir="$repo_root/stow"

# packages to link, one per top-level directory under stow/
packages=(bash zsh git ssh vim kitty)

# create real directories up front so stow links individual files instead of
# folding whole directories into a single symlink. this also keeps ~/.ssh
# private and lets an overlay repo share the same directories.
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.ssh/config.d"
chmod 700 "$HOME/.ssh" "$HOME/.ssh/config.d"

if ! command -v stow >/dev/null 2>&1; then
  echo "stow is not installed. run ./bootstrap/macos.sh or install it first." >&2
  exit 1
fi

for pkg in "${packages[@]}"; do
  echo "stowing $pkg"
  stow --no-folding --restow --dir "$stow_dir" --target "$HOME" "$pkg"
done

echo "stow complete"
