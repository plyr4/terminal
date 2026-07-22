# base environment and prompt
source ~/.zprofile

# aliases and functions
source ~/.zaliases

# machine-local secrets (tokens, passwords). create this file yourself; never commit it
[ -r ~/.zsensitive ] && source ~/.zsensitive

# drop-ins contributed by overlays such as the private/work repo
for f in ~/.config/zsh/*.zsh(N); do
  [ -r "$f" ] && source "$f"
done
unset f

# zsh plugins installed via Homebrew
if command -v brew >/dev/null 2>&1; then
  brew_prefix="$(brew --prefix)"
  export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="$brew_prefix/share/zsh-syntax-highlighting/highlighters"
  [ -r "$brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
    source "$brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  [ -r "$brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
    source "$brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  unset brew_prefix
fi
