# colors
export LS_COLORS="di=38;5;214"
RESET="\[\033[00m\]"
YELLOW="\[\033[93m\]"
CYAN="\[\033[96m\]"
DBLUE="\[\033[36m\]"
ORANGE="\[\033[38;5;214m\]"

# prompt: user, host, working directory, and current git branch
PS1="${debian_chroot:+($debian_chroot)}$CYAN\u$RESET@$YELLOW\h$RESET:$ORANGE\w$RESET $DBLUE\$(__git_ps1 '(%s)')$RESET \$ "

# go
export PATH="$PATH:/usr/local/go/bin"

# aliases and functions
[ -r ~/.bash_aliases ] && source ~/.bash_aliases

# machine-local secrets (tokens, passwords). create this file yourself; never commit it
[ -r ~/.bash_local ] && source ~/.bash_local

# gacp: git add, commit, and push with a confirmation prompt
gacp() {
  if [ "$1" = "" ]; then
    echo "no commit message, aborting."
    return
  fi
  echo "<----"
  echo "-- git status"
  git status
  read -n 1 -p "add commit push? (y/n):   " input
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
