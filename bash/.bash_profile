# colors
export LS_COLORS="di=38;5;214"
RESET="\[\033[00m\]"
YELLOW="\[\033[93m\]"
CYAN="\[\033[96m\]"
DBLUE="\[\033[36m\]"
ORANGE="\[\033[38;5;214m\]"

# terminal git label and color
PS1="${debian_chroot:+($debian_chroot)}$CYAN\u$RESET@$YELLOW\h$RESET:$ORANGE\w$RESET $DBLUE\$(__git_ps1 '(%s)')$RESET \$ "

# go
export PATH=$PATH:/usr/local/go/bin

# misc function definitions
gacp() {
  if [ "$1" = "" ]; then
    echo "no commit message, aborting."
    return
  fi
  echo "<----"
  echo "-- git status"
  git status
  read  -n 1 -p "add commit push? (y/n):   " input
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
