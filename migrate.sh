#!/usr/bin/env bash
# migrate an existing machine onto the stow-managed dotfiles.
# any real file that would collide with a package is moved into a timestamped
# backup directory first, then the packages are linked with stow.
# already-linked files are left untouched, so this is safe to re-run.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
internal_root="$repo_root/vader-terminal-internal"

# packages, mirroring bootstrap/stow.sh and vader-terminal-internal/install.sh.
# keep these in sync if either script changes.
base_packages=(bash zsh git ssh vim kitty)
internal_packages=(git ssh npm zsh)

backup_root="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup}"
dry_run=0
assume_yes=0
run_stow=1
want_internal=auto

if [ -t 1 ]; then
  bold=$'\033[1m'; grn=$'\033[32m'; ylw=$'\033[33m'; dim=$'\033[2m'; rst=$'\033[0m'
else
  bold=; grn=; ylw=; dim=; rst=
fi

usage() {
  cat <<'EOF'
usage: ./migrate.sh [options]

migrate an existing machine onto the stow-managed dotfiles. real files that
would collide with a package are moved into a timestamped backup directory,
then the packages are linked with stow. re-running is safe.

options:
  -n, --dry-run         show what would change, make no changes
  -y, --yes             do not prompt for confirmation
      --no-internal     skip the vader-terminal-internal overlay
      --internal        require the overlay (error if it is missing)
      --no-stow         back up collisions but do not run stow
      --backup-dir DIR  base directory for backups (default: ~/.dotfiles-backup)
  -h, --help            show this help

environment:
  DOTFILES_BACKUP_DIR   same as --backup-dir
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -y|--yes) assume_yes=1 ;;
    --no-internal|--base-only) want_internal=0 ;;
    --internal) want_internal=1 ;;
    --no-stow) run_stow=0 ;;
    --backup-dir) shift; backup_root="${1:-}" ;;
    --backup-dir=*) backup_root="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# resolve whether the overlay should be included
if [ "$want_internal" = auto ]; then
  if [ -d "$internal_root/stow" ]; then want_internal=1; else want_internal=0; fi
elif [ "$want_internal" = 1 ] && [ ! -d "$internal_root/stow" ]; then
  echo "error: --internal given but $internal_root/stow does not exist" >&2
  exit 1
fi

# categorized plan, filled by collect_pkg
plan_linked=()   # already symlinked into the repo, nothing to do
plan_create=()   # target is missing, stow will create it
plan_backup=()   # real file or foreign symlink to move aside first

collect_pkg() {
  local stow_dir="$1" pkg="$2"
  local src_root="$stow_dir/$pkg"
  [ -d "$src_root" ] || { echo "warning: package '$pkg' not found at $src_root" >&2; return 0; }
  local src rel target
  while IFS= read -r -d '' src; do
    rel="${src#"$src_root"/}"
    target="$HOME/$rel"
    if [ "$target" -ef "$src" ]; then
      plan_linked+=("$rel")
    elif [ -L "$target" ] || [ -e "$target" ]; then
      plan_backup+=("$rel")
    else
      plan_create+=("$rel")
    fi
  done < <(find "$src_root" \( -type f -o -type l \) -print0)
}

for pkg in "${base_packages[@]}"; do
  collect_pkg "$repo_root/stow" "$pkg"
done
if [ "$want_internal" -eq 1 ]; then
  for pkg in "${internal_packages[@]}"; do
    collect_pkg "$internal_root/stow" "$pkg"
  done
fi

# report the plan
echo "${bold}migration plan${rst}"
echo "  repo:    $repo_root"
echo "  overlay: $([ "$want_internal" -eq 1 ] && echo "yes ($internal_root)" || echo "no")"
echo ""

if [ "${#plan_backup[@]}" -gt 0 ]; then
  echo "${bold}will back up + relink${rst} (${#plan_backup[@]}):"
  for rel in "${plan_backup[@]}"; do
    if [ -L "$HOME/$rel" ]; then echo "  ${ylw}~/$rel${rst} (symlink)"; else echo "  ${ylw}~/$rel${rst}"; fi
  done
  echo ""
fi

if [ "${#plan_create[@]}" -gt 0 ]; then
  echo "${bold}will link${rst} (${#plan_create[@]}):"
  for rel in "${plan_create[@]}"; do echo "  ${grn}~/$rel${rst}"; done
  echo ""
fi

if [ "${#plan_linked[@]}" -gt 0 ]; then
  echo "${dim}already linked (${#plan_linked[@]}): ${plan_linked[*]}${rst}"
  echo ""
fi

if [ "${#plan_backup[@]}" -eq 0 ] && [ "${#plan_create[@]}" -eq 0 ]; then
  echo "nothing to migrate: every managed file is already linked."
  if [ "$run_stow" -eq 1 ] && [ "$dry_run" -eq 0 ]; then
    echo "re-running stow to be sure..."
  else
    exit 0
  fi
fi

if [ "$dry_run" -eq 1 ]; then
  echo "${dim}dry run: no changes made.${rst}"
  exit 0
fi

# preflight: stow must exist if we intend to link
if [ "$run_stow" -eq 1 ] && ! command -v stow >/dev/null 2>&1; then
  echo "stow is not installed. run ./bootstrap/macos.sh (or brew install stow) first." >&2
  exit 1
fi

# confirm before moving anything
if [ "$assume_yes" -ne 1 ] && [ "${#plan_backup[@]}" -gt 0 ]; then
  printf "back up %d file(s) to %s/<timestamp> and migrate? (y/N) " "${#plan_backup[@]}" "$backup_root"
  read -r reply || reply=""
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "aborted."; exit 1 ;;
  esac
fi

# move collisions into a single timestamped backup directory
if [ "${#plan_backup[@]}" -gt 0 ]; then
  backup_dir="$backup_root/$(date +%Y%m%d%H%M%S)"
  mkdir -p "$backup_dir"
  for rel in "${plan_backup[@]}"; do
    src="$HOME/$rel"
    dest="$backup_dir/$rel"
    mkdir -p "$(dirname "$dest")"
    mv "$src" "$dest"
    echo "backed up ~/$rel -> $dest"
  done
  echo "backups saved under $backup_dir"
  echo ""
fi

# link the packages via the existing bootstrap scripts
if [ "$run_stow" -eq 1 ]; then
  "$repo_root/bootstrap/stow.sh"
  if [ "$want_internal" -eq 1 ]; then
    "$internal_root/install.sh"
  fi
fi

echo ""
echo "${grn}migration complete.${rst} next steps:"
echo "  - verify everything:   ./validate.sh"
echo "  - restart your shell:  exec zsh"
