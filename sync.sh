#!/usr/bin/env bash
# keep the repo in sync with packages installed manually over time.
#
#   ./sync.sh            report drift: packages/casks/taps installed but not in
#                        the Brewfile (and tracked but not installed). read-only.
#   ./sync.sh --dump     regenerate the Brewfile from the current machine (full
#                        snapshot). backs up the old file first. run this before
#                        moving to a new laptop so nothing is lost.
#   ./sync.sh -i         step through the drift one item at a time and keep only
#     (--interactive)    the packages you choose (Enter = keep). each kept item
#                        is appended to the public Brewfile, or the git-ignored
#                        work overlay for private taps/packages.
#
# zsh plugins in this setup are Homebrew packages (zsh-autosuggestions,
# zsh-syntax-highlighting), so they show up in the brew drift below. dotfile
# edits are symlinked into the repo, so they appear under "repo status".
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
brewfile="$repo_root/Brewfile"
internal_brewfile="$repo_root/vader-terminal-internal/Brewfile"

mode=check
assume_yes=0
dump_file="$brewfile"
describe=1
vscode=1

# formula/cask/tap names matching any of these tokens route to the git-ignored
# work overlay instead of the public Brewfile (matched at word/path boundaries,
# so "corp" does not flag "hashicorp"). override with SYNC_PRIVATE_RE; never put
# secrets in the pattern -- this file lives in a public repo.
private_re="${SYNC_PRIVATE_RE:-target|corp|internal|vela}"

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
  -i, --interactive  step through the drift one item at a time; keep only the
                     packages you choose (Enter = keep) and append each to the
                     right file (public Brewfile or the work overlay)
  --dump             regenerate the Brewfile from the current machine state
                     (full snapshot; backs up the existing file first)

options:
  --file FILE        target file for --dump (default: Brewfile)
  --no-describe      omit the "# description" comments (--dump and --interactive)
  --no-vscode        omit VS Code extensions from --dump output
  -y, --yes          do not prompt for confirmation on --dump
  -h, --help         show this help

interactive keys:
  y, Enter           keep the package (write it to the suggested file)
  n                  skip it
  o                  keep it in the other file (toggle Brewfile <-> overlay)
  q                  stop; keep what you have chosen so far

the overlay is vader-terminal-internal/Brewfile. set SYNC_PRIVATE_RE to change
which names route there (default: target|corp|internal|vela).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode=check ;;
    -i|--interactive) mode=interactive ;;
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

# --- interactive capture -----------------------------------------------------

# sorted "installed but not tracked" set difference (have minus want).
drift_list() {
  comm -23 <(printf '%s\n' "$1" | grep -v '^$' | sort -u) \
           <(printf '%s\n' "$2" | grep -v '^$' | sort -u) || true
}

# does a formula/cask/tap name look like work/private config? tokens are matched
# at word/path boundaries so "corp" does not flag "hashicorp".
is_private() {
  printf '%s\n' "$1" | grep -qiE "(^|[^a-z])(${private_re})"'([^a-z]|$)'
}

# one-line description for a formula/cask ($1=formula|cask, $2=name);
# empty when --no-describe is set.
brew_desc() {
  [ "$describe" -eq 1 ] || return 0
  brew desc "--$1" "$2" 2>/dev/null | sed 's/^[^:]*: //' | head -n1 || true
}

# append a Brewfile entry (with an optional "# description" line above) to a
# file, creating it with a header when missing and keeping one trailing newline.
append_entry() {
  local file="$1" line="$2" desc="${3:-}"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then
    if [ "$file" = "$internal_brewfile" ]; then
      printf '# work/private Homebrew overlay (git-ignored, never committed publicly).\n# install with: brew bundle --file=vader-terminal-internal/Brewfile\n\n' >"$file"
    else
      printf '# Homebrew bundle. install with: brew bundle --file=Brewfile\n\n' >"$file"
    fi
  elif [ -s "$file" ] && [ -n "$(tail -c1 "$file")" ]; then
    printf '\n' >>"$file"
  fi
  [ -n "$desc" ] && printf '# %s\n' "$desc" >>"$file"
  printf '%s\n' "$line" >>"$file"
}

run_interactive() {
  if [ ! -t 0 ]; then
    echo "interactive mode needs a terminal (stdin is not a tty)." >&2
    exit 1
  fi

  local dir_has_internal=0
  [ -d "$repo_root/vader-terminal-internal" ] && dir_has_internal=1

  local requested_formulae installed_casks installed_taps
  local tracked_formulae tracked_casks tracked_taps
  requested_formulae="$(brew leaves --installed-on-request || true)"
  installed_casks="$(brew list --cask 2>/dev/null || true)"
  installed_taps="$(brew tap 2>/dev/null || true)"
  # tracked = union of the public Brewfile and the overlay, so anything already
  # captured to either file is not offered again.
  tracked_formulae="$(printf '%s\n%s\n' "$(brewfile_names brew "$brewfile")" "$(brewfile_names brew "$internal_brewfile")")"
  tracked_casks="$(printf '%s\n%s\n' "$(brewfile_names cask "$brewfile")" "$(brewfile_names cask "$internal_brewfile")")"
  tracked_taps="$(printf '%s\n%s\n' "$(brewfile_names tap "$brewfile")" "$(brewfile_names tap "$internal_brewfile")")"

  # candidate order: taps first (present before their formulae), then formulae,
  # then casks. Homebrew's default taps are skipped as noise.
  local -a kinds=() names=()
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in homebrew/core|homebrew/cask) continue ;; esac
    kinds+=("tap"); names+=("$line")
  done < <(drift_list "$installed_taps" "$tracked_taps")
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    kinds+=("brew"); names+=("$line")
  done < <(drift_list "$requested_formulae" "$tracked_formulae")
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    kinds+=("cask"); names+=("$line")
  done < <(drift_list "$installed_casks" "$tracked_casks")

  local total="${#names[@]}"
  if [ "$total" -eq 0 ]; then
    echo "nothing to capture: the Brewfile and overlay already track everything installed on request."
    return 0
  fi

  printf '%sinteractive capture%s  %s(%d items; keep only what you want)%s\n' \
    "$bold" "$rst" "$dim" "$total" "$rst"
  printf '  %sy/Enter%s keep   %sn%s skip   %so%s other file   %sq%s quit\n' \
    "$grn" "$rst" "$dim" "$rst" "$ylw" "$rst" "$dim" "$rst"
  if [ "$dir_has_internal" -eq 1 ]; then
    printf '  %swork/private names route to the overlay; everything else to the Brewfile.%s\n' \
      "$dim" "$rst"
  fi

  local i=0 kept_pub=0 kept_int=0 skipped=0 quit=0
  while [ "$i" -lt "$total" ]; do
    local kind="${kinds[$i]}" name="${names[$i]}"
    i=$((i + 1))

    local desc=""
    case "$kind" in
      brew) desc="$(brew_desc formula "$name")" ;;
      cask) desc="$(brew_desc cask "$name")" ;;
    esac

    local to_internal=0
    if [ "$dir_has_internal" -eq 1 ] && is_private "$name"; then
      to_internal=1
    fi

    while :; do
      local dest_file dest_rel
      if [ "$to_internal" -eq 1 ]; then
        dest_file="$internal_brewfile"; dest_rel="vader-terminal-internal/Brewfile ${ylw}(overlay)${rst}"
      else
        dest_file="$brewfile"; dest_rel="Brewfile"
      fi
      printf '\n%s[%d/%d]%s %s%s%s %s%s%s  %s-> %s%s\n' \
        "$dim" "$i" "$total" "$rst" \
        "$bold" "$kind" "$rst" \
        "$grn" "$name" "$rst" \
        "$dim" "$rst" "$dest_rel"
      [ -n "$desc" ] && printf '        %s%s%s\n' "$dim" "$desc" "$rst"
      printf 'keep? [Y/n/o/q] '
      local reply; read -r reply || reply="q"
      case "$reply" in
        ""|y|Y|yes|YES)
          local entry
          case "$kind" in
            tap) entry="tap \"$name\"" ;;
            brew) entry="brew \"$name\"" ;;
            cask) entry="cask \"$name\"" ;;
          esac
          append_entry "$dest_file" "$entry" "$desc"
          if [ "$to_internal" -eq 1 ]; then kept_int=$((kept_int + 1)); else kept_pub=$((kept_pub + 1)); fi
          break ;;
        n|N|no|NO) skipped=$((skipped + 1)); break ;;
        o|O)
          if [ "$dir_has_internal" -eq 1 ]; then
            to_internal=$((1 - to_internal))
          else
            printf '  %sno overlay directory; staying on the Brewfile%s\n' "$dim" "$rst"
          fi ;;
        q|Q) quit=1; break ;;
        *) printf '  %s? y=keep  n=skip  o=other file  q=quit%s\n' "$dim" "$rst" ;;
      esac
    done

    [ "$quit" -eq 1 ] && break
  done

  [ "$quit" -eq 1 ] && printf '\n%sstopped early.%s\n' "$dim" "$rst"

  section "summary"
  printf '  kept %s%d%s to Brewfile, %s%d%s to overlay, skipped %s%d%s\n' \
    "$grn" "$kept_pub" "$rst" "$ylw" "$kept_int" "$rst" "$dim" "$skipped" "$rst"

  if [ "$kept_pub" -gt 0 ] && git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    section "Brewfile changes"
    git -C "$repo_root" --no-pager diff --stat -- "$brewfile" || true
    cat <<EOF

${dim}review:${rst} git -C "$repo_root" diff -- Brewfile
${dim}commit:${rst} git -C "$repo_root" add Brewfile && git commit -m "brew: track packages"
EOF
  fi

  if [ "$kept_int" -gt 0 ]; then
    local idir="$repo_root/vader-terminal-internal"
    section "vader-terminal-internal/Brewfile changes"
    if git -C "$idir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -C "$idir" --no-pager diff --stat -- Brewfile || true
      printf '\n%scommit in the overlay repo:%s git -C "%s" add Brewfile && git commit\n' \
        "$dim" "$rst" "$idir"
    else
      printf '  %swrote %s%s\n' "$dim" "$internal_brewfile" "$rst"
    fi
  fi
}

case "$mode" in
  check) run_check ;;
  interactive) run_interactive ;;
  dump) run_dump ;;
esac
