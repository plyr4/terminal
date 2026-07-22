#!/usr/bin/env bash
# verify the stow-managed dotfiles are linked and wired correctly.
# read-only: makes no changes. exits non-zero if any required check fails.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
internal_root="$repo_root/vader-terminal-internal"

# packages, mirroring bootstrap/stow.sh and vader-terminal-internal/install.sh.
base_packages=(bash zsh git ssh vim kitty)
internal_packages=(git ssh npm zsh)

if [ -t 1 ]; then
  bold=$'\033[1m'; red=$'\033[31m'; grn=$'\033[32m'; ylw=$'\033[33m'; dim=$'\033[2m'; rst=$'\033[0m'
else
  bold=; red=; grn=; ylw=; dim=; rst=
fi

ok=0; bad=0; warns=0

section() { printf '\n%s%s%s\n' "$bold" "$1" "$rst"; }
pass() { printf '  %s✓%s %s\n' "$grn" "$rst" "$1"; ok=$((ok + 1)); }
fail() { printf '  %s✗%s %s\n' "$red" "$rst" "$1"; bad=$((bad + 1)); }
warn() { printf '  %s!%s %s\n' "$ylw" "$rst" "$1"; warns=$((warns + 1)); }
info() { printf '  %s·%s %s\n' "$dim" "$rst" "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# confirm every file in a package is a symlink pointing back into the repo
check_pkg_links() {
  local stow_dir="$1" pkg="$2"
  local src_root="$stow_dir/$pkg"
  if [ ! -d "$src_root" ]; then
    warn "package '$pkg' not found at $src_root"
    return
  fi
  local src rel target
  while IFS= read -r -d '' src; do
    rel="${src#"$src_root"/}"
    target="$HOME/$rel"
    if [ -L "$target" ] && [ "$target" -ef "$src" ]; then
      pass "~/$rel"
    elif [ ! -e "$target" ] && [ ! -L "$target" ]; then
      fail "~/$rel is missing (run ./migrate.sh)"
    elif [ ! -L "$target" ]; then
      fail "~/$rel is a real file, not a symlink (run ./migrate.sh)"
    else
      fail "~/$rel is a symlink but does not point into the repo"
    fi
  done < <(find "$src_root" \( -type f -o -type l \) -print0)
}

# grep a file (following symlinks) for a wiring hook
check_hook() {
  local file="$1" pattern="$2" label="$3"
  if [ ! -e "$file" ]; then
    fail "$label: $file not found"
  elif grep -Eq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label: hook not found in $file"
  fi
}

section "base packages"
for pkg in "${base_packages[@]}"; do
  check_pkg_links "$repo_root/stow" "$pkg"
done

section "vader-terminal-internal overlay"
if [ -d "$internal_root/stow" ]; then
  for pkg in "${internal_packages[@]}"; do
    check_pkg_links "$internal_root/stow" "$pkg"
  done
else
  info "not installed (optional), skipping"
fi

section "hook wiring"
check_hook "$HOME/.gitconfig" 'config/git/internal\.gitconfig' "gitconfig includes internal overlay"
check_hook "$HOME/.ssh/config" '^[[:space:]]*Include[[:space:]]+.*config\.d' "ssh config includes config.d/*.conf"
check_hook "$HOME/.zshrc" 'config/zsh/\*\.zsh' "zshrc sources ~/.config/zsh/*.zsh"

section "shell syntax"
if have zsh; then
  for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zaliases"; do
    if [ ! -e "$f" ]; then
      fail "${f/#$HOME/~} is missing"
    elif zsh -n "$f" 2>/dev/null; then
      pass "zsh -n ${f/#$HOME/~}"
    else
      fail "zsh -n ${f/#$HOME/~} reported a syntax error"
    fi
  done
else
  warn "zsh not found, skipping zsh syntax checks"
fi
if have bash; then
  for f in "$HOME/.bash_profile" "$HOME/.bash_aliases"; do
    if [ ! -e "$f" ]; then
      fail "${f/#$HOME/~} is missing"
    elif bash -n "$f" 2>/dev/null; then
      pass "bash -n ${f/#$HOME/~}"
    else
      fail "bash -n ${f/#$HOME/~} reported a syntax error"
    fi
  done
fi

section "ssh config"
if have ssh; then
  if ssh -G github.com >/dev/null 2>&1; then
    pass "ssh config parses (ssh -G github.com)"
  else
    fail "ssh -G github.com failed to parse the config"
  fi
  if [ -d "$internal_root/stow" ]; then
    if ssh -G git.target.com >/dev/null 2>&1; then
      pass "ssh config parses (ssh -G git.target.com)"
    else
      warn "ssh -G git.target.com failed (overlay host)"
    fi
  fi
else
  warn "ssh not found, skipping ssh config check"
fi

section "git identity"
if have git; then
  name="$(git config --get user.name || true)"
  email="$(git config --get user.email || true)"
  if [ -n "$name" ] && [ -n "$email" ]; then
    pass "git identity: $name <$email>"
  else
    fail "git user.name / user.email is not set"
  fi
else
  warn "git not found"
fi

section "tools (from Brewfile)"
for t in git stow nvim rg gh go node kitty; do
  if have "$t"; then
    info "$t present"
  else
    warn "$t not found (Brewfile installs it; run brew bundle)"
  fi
done

section "local + optional"
if [ -r "$HOME/.zsensitive" ]; then
  info "~/.zsensitive present (machine-local secrets, sourced by zsh)"
else
  info "~/.zsensitive absent (optional; create it for machine-local secrets)"
fi
if [ -d "$HOME/.config/nvim/.git" ]; then
  info "neovim config is a git checkout"
else
  warn "neovim config not installed (run ./bootstrap/neovim.sh)"
fi

printf '\n%ssummary%s: %s%d passed%s, %s%d failed%s, %s%d warnings%s\n' \
  "$bold" "$rst" \
  "$grn" "$ok" "$rst" \
  "$red" "$bad" "$rst" \
  "$ylw" "$warns" "$rst"

if [ "$bad" -gt 0 ]; then
  printf '%s✗ validation failed.%s run ./migrate.sh, then re-run ./validate.sh\n' "$red" "$rst"
  exit 1
fi
printf '%s✓ all required checks passed.%s\n' "$grn" "$rst"
