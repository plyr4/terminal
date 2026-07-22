#!/usr/bin/env bash
# keep the repo in sync with packages installed manually over time.
#
#   ./sync.sh            report drift: packages/casks/taps installed but not in
#                        the Brewfile (and tracked but not installed). read-only.
#   ./sync.sh --dump     regenerate the Brewfile from the current machine (full
#                        snapshot). backs up the old file first. run this before
#                        moving to a new laptop so nothing is lost.
#
# zsh plugins in this setup are Homebrew packages (zsh-autosuggestions,
# zsh-syntax-highlighting), so they show up in the brew drift below. dotfile
# edits are symlinked into the repo, so they appear under "repo status".
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
brewfile="$repo_root/Brewfile"

mode=check
assume_yes=0
dump_file="$brewfile"
describe=1
vscode=1

if [ -t 1 ]; then
  bold=$'\033[1m'; grn=$'\033[32m'; ylw=$'\033[33m'; red=$'\033[31m'; dim=$'\033[2m'; rst=$'\033[0m'
else
  bold=; grn=; ylw=; red=; dim=; rst=
fi

usage() {
  cat <<'EOF'
usage: ./sync.sh [options]

report or capture packages installed manually over time so the repo Brewfile
stays the single source of truth.

modes:
  (default)          report drift only, make no changes
  --dump             regenerate the Brewfile from the current machine state
                     (full snapshot; backs up the existing file first)

options:
  --file FILE        target file for --dump (default: Brewfile)
  --no-describe      omit the "# description" comments in --dump output
  --no-vscode        omit VS Code extensions from --dump output
  -y, --yes          do not prompt for confirmation on --dump
  -h, --help         show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode=check ;;
    --dump) mode=dump ;;
    --file) shift; dump_file="${1:-}" ;;
    --file=*) dump_file="${1#*=}" ;;
    --no-describe) describe=0 ;;
    --no-vscode) vscode=0 ;;
    -y|--yes) assume_yes=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if ! command -v brew >/dev/null 2>&1; then
  echo "brew not found. install Homebrew first (see ./bootstrap/macos.sh)." >&2
  exit 1
fi

# extract the quoted names of a given entry type from a Brewfile
brewfile_names() {
  local type="$1" file="$2"
  [ -f "$file" ] || return 0
  grep -E "^[[:space:]]*${type}[[:space:]]+\"" "$file" 2>/dev/null \
    | sed -E "s/^[[:space:]]*${type}[[:space:]]+\"([^\"]+)\".*/\1/" || true
}

section() { printf '\n%s%s%s\n' "$bold" "$1" "$rst"; }

# print the set difference of two newline lists, colored, with a count header
report_diff() {
  local title="$1" have="$2" want="$3" color="$4"
  local diff n
  diff="$(comm -23 <(printf '%s\n' "$have" | grep -v '^$' | sort -u) \
                   <(printf '%s\n' "$want" | grep -v '^$' | sort -u) || true)"
  n="$(printf '%s' "$diff" | grep -c . || true)"
  printf '\n%s%s (%s)%s\n' "$bold" "$title" "$n" "$rst"
  if [ -z "$diff" ]; then
    printf '  %s(none)%s\n' "$dim" "$rst"
  else
    while IFS= read -r line; do
      [ -n "$line" ] && printf '  %s%s%s\n' "$color" "$line" "$rst"
    done <<<"$diff"
  fi
}

run_check() {
  local requested_formulae all_formulae installed_casks installed_taps
  local tracked_formulae tracked_casks tracked_taps
  # top-level packages you asked for (excludes dependencies) -> clean "add" list
  requested_formulae="$(brew leaves --installed-on-request || true)"
  # everything installed, including dependencies -> accurate "is it present" check
  all_formulae="$(brew list --formula 2>/dev/null || true)"
  installed_casks="$(brew list --cask 2>/dev/null || true)"
  installed_taps="$(brew tap || true)"
  tracked_formulae="$(brewfile_names brew "$brewfile")"
  tracked_casks="$(brewfile_names cask "$brewfile")"
  tracked_taps="$(brewfile_names tap "$brewfile")"

  echo "${bold}drift report${rst}  (Brewfile: $brewfile)"

  report_diff "formulae installed but NOT in Brewfile (add these)" \
    "$requested_formulae" "$tracked_formulae" "$grn"
  report_diff "formulae in Brewfile but NOT installed (remove or install)" \
    "$tracked_formulae" "$all_formulae" "$ylw"
  report_diff "casks installed but NOT in Brewfile (add these)" \
    "$installed_casks" "$tracked_casks" "$grn"
  report_diff "casks in Brewfile but NOT installed (remove or install)" \
    "$tracked_casks" "$installed_casks" "$ylw"
  report_diff "taps added but NOT in Brewfile (add these)" \
    "$installed_taps" "$tracked_taps" "$grn"

  section "repo status (uncommitted dotfile/config changes)"
  if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local changes
    changes="$(git -C "$repo_root" status --short || true)"
    if [ -n "$changes" ]; then
      printf '%s\n' "$changes" | sed 's/^/  /'
    else
      printf '  %sclean%s\n' "$dim" "$rst"
    fi
  else
    printf '  %snot a git repo%s\n' "$dim" "$rst"
  fi

  cat <<EOF

${dim}next:${rst}
  - add the formulae/casks/taps you want to keep to $brewfile (curated), or
  - run ${bold}./sync.sh --dump${rst} to snapshot everything into the Brewfile, then
  - commit the changes: git -C "$repo_root" add -A && git commit
EOF
}

run_dump() {
  local args=(--force --file="$dump_file")
  [ "$describe" -eq 1 ] && args+=(--describe)
  [ "$vscode" -eq 0 ] && args+=(--no-vscode)

  if [ -e "$dump_file" ] && [ "$assume_yes" -ne 1 ]; then
    printf "this overwrites %s with a full snapshot (curated comments/sections are lost).\n" "$dump_file"
    printf "the old file is backed up and the change is reversible with git. continue? (y/N) "
    local reply; read -r reply || reply=""
    case "$reply" in y|Y|yes|YES) ;; *) echo "aborted."; exit 1 ;; esac
  fi

  if [ -e "$dump_file" ]; then
    local backup="${dump_file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$dump_file" "$backup"
    echo "backed up $dump_file -> $backup"
  fi

  brew bundle dump "${args[@]}"
  echo "wrote snapshot to $dump_file"

  # a full snapshot can capture work/private taps and packages. surface anything
  # that looks private so it is never committed to a public repo by accident.
  local nonstd_taps priv_urls
  nonstd_taps="$(grep -E '^tap ' "$dump_file" 2>/dev/null | grep -vE '"homebrew/(core|cask)"' || true)"
  priv_urls="$(grep -nE 'git@|(target|corp|internal)\.' "$dump_file" 2>/dev/null || true)"
  if [ -n "$nonstd_taps" ] || [ -n "$priv_urls" ]; then
    printf '\n%s! review before committing to a public repo%s\n' "$ylw" "$rst"
    printf '%s  the snapshot may include work/private taps or packages.%s\n' "$dim" "$rst"
    if [ -n "$nonstd_taps" ]; then
      echo "  non-default taps:"
      printf '%s\n' "$nonstd_taps" | sed 's/^/    /'
    fi
    if [ -n "$priv_urls" ]; then
      echo "  lines with private-looking URLs:"
      printf '%s\n' "$priv_urls" | sed 's/^/    /'
    fi
    printf '%s  tip: capture work packages into the git-ignored overlay instead:%s\n' "$dim" "$rst"
    printf '       ./sync.sh --dump --file vader-terminal-internal/Brewfile\n'
  fi

  if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    section "git diff --stat"
    git -C "$repo_root" --no-pager diff --stat -- "$dump_file" || true
    cat <<EOF

${dim}review with:${rst} git -C "$repo_root" diff -- "$dump_file"
${dim}revert with:${rst} git -C "$repo_root" checkout -- "$dump_file"
${dim}commit with:${rst} git -C "$repo_root" add "$dump_file" && git commit -m "brew: snapshot packages"
EOF
  fi
}

case "$mode" in
  check) run_check ;;
  dump) run_dump ;;
esac
