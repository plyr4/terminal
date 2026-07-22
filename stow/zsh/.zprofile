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

# nvm, installed via Homebrew
if command -v brew >/dev/null 2>&1; then
  export NVM_DIR="$HOME/.nvm"
  nvm_prefix="$(brew --prefix nvm 2>/dev/null || true)"
  [ -s "$nvm_prefix/nvm.sh" ] && \. "$nvm_prefix/nvm.sh"
  [ -s "$nvm_prefix/etc/bash_completion.d/nvm" ] && \. "$nvm_prefix/etc/bash_completion.d/nvm"
  unset nvm_prefix
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
