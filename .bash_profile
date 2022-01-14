# colors
export LS_COLORS="di=38;5;214"
# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    # Colors
    RESET="\[\033[00m\]"
    YELLOW="\[\033[93m\]"
    CYAN="\[\033[96m\]"
    DBLUE="\[\033[36m\]"
    ORANGE="\[\033[38;5;214m\]"
    # export PS1="\[$CYAN\u$RESET@$YELLOW\h $TAN\W$DBLUE\$(__git_ps1)$RESET $\] "

    PS1="${debian_chroot:+($debian_chroot)}$CYAN\u$RESET@$YELLOW\h$RESET:$ORANGE\w$RESET $DBLUE\$(__git_ps1 '(%s)')$RESET \$ "
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

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
