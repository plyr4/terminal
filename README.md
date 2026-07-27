# terminal

machine dotfiles managed with [chezmoi](https://www.chezmoi.io).

`chezmoi` maps [`dotfiles/`](dotfiles/) into `$HOME`.

## Install

```sh
git clone https://github.com/plyr4/terminal
cd terminal
chezmoi init --source . --apply .
```

during `init` chezmoi will ask:
- **Is this a work machine?** — default no
- **Manage the neovim config?** — clones the AstroNvim fork into `~/.config/nvim`, default yes
- **Terminal to install (kitty/ghostty)?** — default kitty
- **GPG key ID for signing git commits?** — pre-filled with the local secret key matching your git
  email (the IDs shown by `gpg --list-secret-keys --keyid-format=long`); press enter to accept, paste
  a different ID, or leave blank to disable commit signing

answers are saved in `~/.config/chezmoi/chezmoi.toml`

on first `apply` the bootstrap scripts in [`dotfiles/.chezmoiscripts`](dotfiles/.chezmoiscripts) run automatically

> if you're working from a fork (e.g. for a work profile), clone the fork instead
> the same `chezmoi init --source . --apply .` command applies.

## Everyday tasks

```sh
chezmoi edit ~/.zshrc     # open a file's source in $EDITOR
chezmoi apply             # write source -> $HOME
chezmoi diff              # preview what would change
chezmoi status            # short status
chezmoi update            # git pull + apply in one step
chezmoi doctor            # diagnose problems
```

edit a file directly in `$HOME` then use these to keep the changes:

```sh
chezmoi re-add            # pull $HOME changes back into source
chezmoi cd                # jump into the source dir (dotfiles/)
git add -A && git commit -m "..." && git push
```

## Adding a file

```sh
chezmoi add ~/.config/foo/foo.conf     # import as-is
chezmoi add --encrypt ~/.some-secret   # import encrypted
```

chezmoi names it automatically (`dot_`, `private_`, `executable_`, …). Commit from `chezmoi cd`.

## Homebrew

[`Brewfile`](Brewfile) is the source of truth. `chezmoi apply` runs `brew bundle` automatically when it changes

to capture packages installed by hand:

```sh
cd "$(chezmoi source-path)/.."
brew bundle dump --force     # overwrite Brewfile from current machine state
brew bundle check            # what's in Brewfile but missing?
```

## Commit signing

git commit signing is driven by the `signingkey` answer from `chezmoi init` and rendered into
`~/.config/git/config`:

- a non-empty key sets `user.signingkey` and `commit.gpgsign = true`
- a blank answer sets `commit.gpgsign = false`, so commits still work on machines without your key

on a new machine, import (or create) your key first, then run `chezmoi init` — the prompt
auto-detects the secret key whose uid matches your git email:

```sh
gpg --list-secret-keys --keyid-format=long   # confirm the key is present
chezmoi init                                 # accept the detected key at the prompt
```

`gnupg` is installed via the [`Brewfile`](Brewfile). if you pull this change onto a machine that was
already set up, re-run `chezmoi init` once so the new `signingkey` value is written to your chezmoi
config (existing answers are preserved).

## Secrets

`~/.zsensitive` (zsh) and `~/.bash_local` (bash) are sourced on shell start if present:

```sh
echo 'export GITHUB_TOKEN=...' >> ~/.zsensitive
```

to version-control a secret with encryption:

```sh
age-keygen -o ~/.config/chezmoi/key.txt     # generate key once
chezmoi edit-config                         # uncomment the [age] block
chezmoi add --encrypt ~/.zsensitive         # now it's safe to commit
```
