# pnpm-guard.zsh — blocks npm dependency-management commands inside pnpm projects.
#
# Sourced automatically by ~/.zshrc via the ~/.config/zsh/*.zsh drop-in pattern.
# No manual sourcing is required.
#
# HOW DETECTION WORKS
#   Walks upward from $PWD checking for pnpm signals in precedence order:
#     1. package.json contains "packageManager": "pnpm@..."  (explicit declaration)
#     2. pnpm-workspace.yaml exists at or above $PWD        (workspace root)
#     3. pnpm-lock.yaml exists at or above $PWD             (lockfile)
#   The walk stops as soon as the strongest signal (#1) is found. Signals #2/#3
#   record the first (closest to $PWD) match and are returned after the full walk
#   if no packageManager field is found.
#
# ESCAPE HATCH
#   Prepend --allow-npm to bypass the guard for one invocation:
#     npm --allow-npm install          # runs the real npm install
#   --allow-npm is stripped before the args reach the real npm binary.
#
# DEBUG MODE
#   Set NPM_PNPM_GUARD_DEBUG=1 to print detection details on every npm call.
#
# LIMITATIONS
#   - Only guards interactive shell invocations. Child processes (e.g., scripts
#     run via `npm run build`) call the npm binary directly and are not affected.
#   - `command npm …`, `env npm …`, and other exec-style bypasses skip the guard
#     by design — this keeps the guard focused on interactive use.
#   - Flags placed before the subcommand (e.g. `npm --workspace=foo install`) are
#     not included in the suggested pnpm equivalent but the command is still blocked.

# _npm_pnpm_root: walk upward from $PWD looking for pnpm project signals.
# On success prints "signal<TAB>project_root" to stdout and returns 0.
# Returns 1 when no pnpm project is found.
_npm_pnpm_root() {
  local dir="$PWD"
  local fallback_signal="" fallback_dir=""

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]] && \
       command grep -qE '"packageManager"\s*:\s*"pnpm@' "$dir/package.json" 2>/dev/null; then
      printf '%s\t%s\n' "package.json#packageManager" "$dir"
      return 0
    fi

    if [[ -z "$fallback_signal" ]]; then
      if [[ -f "$dir/pnpm-workspace.yaml" ]]; then
        fallback_signal="pnpm-workspace.yaml"
        fallback_dir="$dir"
      elif [[ -f "$dir/pnpm-lock.yaml" ]]; then
        fallback_signal="pnpm-lock.yaml"
        fallback_dir="$dir"
      fi
    elif [[ "$fallback_signal" == "pnpm-lock.yaml" && -f "$dir/pnpm-workspace.yaml" ]]; then
      # upgrade to the stronger workspace signal if found higher up
      fallback_signal="pnpm-workspace.yaml"
      fallback_dir="$dir"
    fi

    dir="${dir:h}"
  done

  if [[ -n "$fallback_signal" ]]; then
    printf '%s\t%s\n' "$fallback_signal" "$fallback_dir"
    return 0
  fi

  return 1
}

# _npm_is_dep_cmd: returns 0 when the argument list represents an npm
# dependency-management subcommand that should be blocked in a pnpm project.
# Returns 1 for version/help/config/publish and other non-dependency commands,
# and also returns 1 when --allow-npm is present anywhere in the args.
_npm_is_dep_cmd() {
  for arg in "$@"; do
    [[ "$arg" == "--allow-npm" ]] && return 1
  done

  local subcmd=""
  for arg in "$@"; do
    [[ "$arg" == -* ]] && continue
    subcmd="$arg"
    break
  done

  [[ -z "$subcmd" ]] && return 1

  case "$subcmd" in
    install|i|ci|add|uninstall|remove|rm|un|r|update|up|upgrade|dedupe|ddp|find-dupes)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# _npm_pnpm_suggestion: print the idiomatic pnpm equivalent for a given npm
# subcommand and its arguments.
_npm_pnpm_suggestion() {
  local subcmd="$1"; shift
  local args=("$@")

  local has_pkgs=0
  for a in "${args[@]}"; do
    [[ "$a" != -* ]] && has_pkgs=1 && break
  done

  case "$subcmd" in
    install|i)
      if [[ $has_pkgs -eq 1 ]]; then
        printf 'pnpm add %s\n' "${args[*]}"
      else
        printf 'pnpm install'
        [[ ${#args[@]} -gt 0 ]] && printf ' %s' "${args[*]}"
        printf '\n'
      fi ;;
    ci)
      printf 'pnpm install --frozen-lockfile\n' ;;
    add)
      printf 'pnpm add %s\n' "${args[*]}" ;;
    uninstall|remove|rm|un|r)
      printf 'pnpm remove %s\n' "${args[*]}" ;;
    update|up|upgrade)
      printf 'pnpm update'
      [[ ${#args[@]} -gt 0 ]] && printf ' %s' "${args[*]}"
      printf '\n' ;;
    dedupe|ddp|find-dupes)
      printf 'pnpm dedupe\n' ;;
    *)
      printf 'pnpm %s' "$subcmd"
      [[ ${#args[@]} -gt 0 ]] && printf ' %s' "${args[*]}"
      printf '\n' ;;
  esac
}

# npm: wrapper around the real npm binary.
#
# When the subcommand is a dependency-management operation AND the current
# working directory is inside a pnpm-managed project, the command is blocked
# and a warning with the pnpm equivalent is printed to stderr.
#
# This function supersedes the nvm lazy-loader defined in ~/.zprofile. The
# passthrough path re-invokes nvm's _load_nvm if it is still present so that
# the real npm binary is properly resolved before execution.
npm() {
  local pnpm_info="" is_dep_cmd=0
  _npm_is_dep_cmd "$@" && is_dep_cmd=1

  if [[ $is_dep_cmd -eq 1 || "${NPM_PNPM_GUARD_DEBUG:-0}" == "1" ]]; then
    pnpm_info="$(_npm_pnpm_root)"
  fi

  if [[ "${NPM_PNPM_GUARD_DEBUG:-0}" == "1" ]]; then
    if [[ -n "$pnpm_info" ]]; then
      printf '[pnpm-guard] pnpm project: %s at %s\n' \
        "${pnpm_info%%$'\t'*}" "${pnpm_info##*$'\t'}" >&2
    else
      printf '[pnpm-guard] no pnpm project detected (cwd: %s)\n' "$PWD" >&2
    fi
  fi

  if [[ $is_dep_cmd -eq 1 && -n "$pnpm_info" ]]; then
    local signal="${pnpm_info%%$'\t'*}"
    local proj_root="${pnpm_info##*$'\t'}"

    local subcmd="" subcmd_found=0 subcmd_args=()
    for arg in "$@"; do
      if [[ $subcmd_found -eq 0 && "$arg" != -* ]]; then
        subcmd="$arg"; subcmd_found=1
      elif [[ $subcmd_found -eq 1 ]]; then
        subcmd_args+=("$arg")
      fi
    done

    local suggestion
    suggestion="$(_npm_pnpm_suggestion "$subcmd" "${subcmd_args[@]}")"

    printf '\n\033[33m⚠️  This project is managed by pnpm.\033[0m\n' >&2
    printf '   You ran: npm %s\n' "$*" >&2
    printf '   Use:     %s\n' "$suggestion" >&2
    printf '\n' >&2
    printf 'Detected: %s\n' "$signal" >&2
    printf 'Project:  %s\n\n' "$proj_root" >&2
    return 1
  fi

  # Passthrough: strip --allow-npm before forwarding to the real npm binary.
  # If nvm's lazy-loader is still active (_load_nvm is defined), invoke it now
  # so the real npm binary is in PATH; _load_nvm unsets this npm() function as
  # a side effect, so the subsequent `npm` call resolves to the binary.
  local real_args=("${(@)@:#--allow-npm}")
  if typeset -f _load_nvm > /dev/null 2>&1; then
    _load_nvm
    npm "${real_args[@]}"
  else
    command npm "${real_args[@]}"
  fi
}
