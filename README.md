# terminal

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io).

Source lives under [`dotfiles/`](dotfiles/). chezmoi maps it 1:1 onto `$HOME`.
Edit the source, run `chezmoi apply`, done.

## install

```sh
git clone https://github.com/plyr4/terminal
cd terminal
chezmoi init --source . --apply .
```

During `init` chezmoi will ask:
- **Is this a work machine?** — default no
- **Manage the neovim config?** — clones the AstroNvim fork into `~/.config/nvim`, default yes

Answers are saved in `~/.config/chezmoi/chezmoi.toml`. On first apply, bootstrap scripts
run automatically: Xcode CLT + Homebrew (macOS), then `brew bundle` from the [`Brewfile`](Brewfile).

Restart the shell when it's done: `exec zsh`

> If you're working from a fork (e.g. for a work profile), clone the fork instead —
> the same `chezmoi init --source . --apply .` command applies.

## everyday

```sh
chezmoi edit ~/.zshrc     # open a file's source in $EDITOR
chezmoi apply             # write source -> $HOME
chezmoi diff              # preview what would change
chezmoi status            # short status
chezmoi update            # git pull + apply in one step
chezmoi doctor            # diagnose problems
```

Edited a file directly in `$HOME` and want to keep it?

```sh
chezmoi re-add            # pull $HOME changes back into source
chezmoi cd                # jump into the source dir (dotfiles/)
git add -A && git commit -m "..." && git push
```

## adding a file

```sh
chezmoi add ~/.config/foo/foo.conf     # import as-is
chezmoi add --encrypt ~/.some-secret   # import encrypted
```

chezmoi names it automatically (`dot_`, `private_`, `executable_`, …). Commit from `chezmoi cd`.

## Homebrew

[`Brewfile`](Brewfile) is the source of truth. `chezmoi apply` runs `brew bundle` automatically
when it changes. To capture packages installed by hand:

```sh
cd "$(chezmoi source-path)/.."
brew bundle dump --force     # overwrite Brewfile from current machine state
brew bundle check            # what's in Brewfile but missing?
```

## secrets

`~/.zsensitive` (zsh) and `~/.bash_local` (bash) are sourced on shell start if present — never committed.

```sh
echo 'export GITHUB_TOKEN=...' >> ~/.zsensitive
```

To version-control a secret with encryption:

```sh
age-keygen -o ~/.config/chezmoi/key.txt   # generate key once
chezmoi edit-config                        # uncomment the [age] block
chezmoi add --encrypt ~/.zsensitive        # now it's safe to commit
```

## license

MIT
