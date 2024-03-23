# source bash_profile
source ~/.zprofile

# source bash_aliases
source ~/.zaliases

# zsh-syntax-highlighting
source ~/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export ZSH_HIGHLIGHT_STYLES[comment]='none'

# zsh-autosuggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# apply a custom aliases if .zaliases exists in the current directory
function chpwd() {
  if [ -r $PWD/.zaliases ]; then
    source $PWD/.zaliases
  else
    source $HOME/.zaliases
  fi
}
