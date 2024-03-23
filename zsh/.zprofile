# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# ansible
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# kitty terminal
autoload -U select-word-style
select-word-style bash
bindkey "\e[1;3D" backward-word # ⌥←
bindkey "\e[1;3C" forward-word # ⌥→

# kubernetes
export KUBECONFIG="${HOME}/.kube/config:${HOME}/.kube/config-contexts:${HOME}/.kube/config-base"

# zsh fancy prompt
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '(%b) '
setopt PROMPT_SUBST
PROMPT='%F{36}%n%f:%F{208}~${PWD#$HOME}%f %F{178}${vcs_info_msg_0_}%f%F{12}#%f '

# nvm
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# go
export PATH=$PATH:/usr/local/go/bin

# misc function definitions

# gacp: git add commit push
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

# dockerprune: remove stale docker resources
dockerprune() {
  docker system prune -f -a --volumes
}

# checkout a fork PR
copr() { git fetch origin "refs/pull/$1/head:cpr/$1" && git checkout "cpr/$1"; }
alias co-pr="copr"

# vl: vault login using ldap, sets VAULT_TOKEN to result
vl() {
  echo "running vault login --method=ldap and setting output to VAULT_TOKEN"
  export VAULT_TOKEN=""
  export VAULT_TOKEN=$(vault login --method=ldap | grep 'token                  s.' | awk '{ print $2 }')
  if [ "$VAULT_TOKEN" = "" ]; then
    echo "error running vault login. no VAULT_TOKEN set."
    return
  fi
  echo "set VAULT_TOKEN to $VAULT_TOKEN"
}
