# colors
export LS_COLORS="di=38;5;214"

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
