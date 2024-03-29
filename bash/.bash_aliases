# bashrc edits
alias cbp='code ~/.bash_profile'
alias sbp='source ~/.bashrc'

# ls
alias ls='ls -aGp'

# copy progress bar
alias cpv='rsync -ah --info=progress2'

# diff
alias diff='colordiff'

# other
alias c='clear'
alias squish='export PS1="${debian_chroot:+($debian_chroot)}$ORANGE\W$RESET$RESET \$ "'

# vim
alias vi=vim
alias svi='sudo vi'
alias vis='vim "+set si"'
alias edit='vim'
alias vi,='vi .'
alias vi.='vi .'
alias vim,='vim ,'
alias vim.='vim .'

# change directory
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'
alias cdd='cd ~/dev'
alias cde='cdd; cd external'
alias cdgv='cde; cd go-vela'
alias cdui='cdgv; cd ui'
alias cdhv='cdi; cd davidvader; cd heyvela;'
alias vnvc='cd ~/.config/nvim; nvim'

# grep
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# vscode
alias code,='code .'
alias code.='code .'
code() {
    if [[ $@ == "," ]]; then
        command code .
    else
        command code "$@"
    fi
}

