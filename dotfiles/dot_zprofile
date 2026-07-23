# homebrew (apple silicon or intel)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# base64url::decode: decode a base64url string read from stdin
base64url::decode() {
  awk '{ if (length($0) % 4 == 3) print $0"="; else if (length($0) % 4 == 2) print $0"=="; else print $0; }' | tr -- '-_' '+/' | base64 -d
}

# avoid objc fork crashes with tools like Ansible on macos
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# kitty: bash-style word boundaries and alt-arrow word navigation
autoload -U select-word-style
select-word-style bash
bindkey "\e[1;3D" backward-word
bindkey "\e[1;3C" forward-word

# kubernetes: merge kubeconfig files if present
export KUBECONFIG="${HOME}/.kube/config:${HOME}/.kube/config-contexts:${HOME}/.kube/config-base"

# prompt: user, working directory, and current git branch
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '(%b) '
setopt PROMPT_SUBST
PROMPT='%F{36}%n%f:%F{208}~${PWD#$HOME}%f %F{178}${vcs_info_msg_0_}%f%F{12}#%f '

# go
export PATH="$PATH:/usr/local/go/bin"

# nvm (Homebrew). eagerly sourcing nvm.sh costs several seconds per shell (it
# auto-selects a node version and loads completions), so lazy-load it: the first
# call to nvm/node/npm/npx/corepack sources nvm for real and then runs.
export NVM_DIR="$HOME/.nvm"
if [ -s "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/nvm/nvm.sh" ]; then
  _load_nvm() {
    local d="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/nvm"
    unset -f nvm node npm npx corepack 2>/dev/null
    \. "$d/nvm.sh"
    [ -s "$d/etc/bash_completion.d/nvm" ] && \. "$d/etc/bash_completion.d/nvm"
    rehash 2>/dev/null || true
  }
  for nvm_cmd in nvm node npm npx corepack; do
    eval "${nvm_cmd}() { _load_nvm; ${nvm_cmd} \"\$@\"; }"
  done
  unset nvm_cmd
fi

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# gacp: git add, commit, and push with a confirmation prompt
gacp() {
  if [ "$1" = "" ]; then
    echo "no commit message, aborting."
    return
  fi
  echo "<----"
  echo "-- git status"
  git status
  echo "add commit push? (y/n):   "
  read input
  echo ""
  if [ "$input" = "y" ]; then
    echo "-- git add ."
    git add .
    echo "-- git commit -m \"$1\""
    git commit -m "$1"
    git push
  else
    echo "not y, aborting."
  fi
  echo "---->"
}

# dockerprune: remove unused docker images, containers, and volumes
dockerprune() {
  docker system prune -f -a --volumes
}

# copr: fetch and check out a pull request by number
copr() { git fetch origin "refs/pull/$1/head:cpr/$1" && git checkout "cpr/$1"; }
alias co-pr="copr"
