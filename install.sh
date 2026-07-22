#!/usr/bin/env bash
# entry point for a fresh machine: install prerequisites, then link dotfiles.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root"

os="$(uname -s)"
case "$os" in
  Darwin) ./bootstrap/macos.sh ;;
  Linux) ./bootstrap/linux.sh ;;
  *)
    echo "unsupported operating system: $os" >&2
    exit 1
    ;;
esac

./bootstrap/stow.sh

echo ""
echo "install complete. next steps:"
echo "  - restart your shell (or 'source ~/.zshrc')"
echo "  - optional neovim config:  ./bootstrap/neovim.sh"
echo "  - optional private overlay: ./vader-terminal-internal/install.sh"
