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
- **GPG key ID for internal/work repos?** — pre-filled with the local secret key matching your work git
  email (`david.vader@target.com`); used for GHEC and internal Target repos; press enter to accept, paste
  a different ID, or leave blank to disable commit signing on internal repos

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

the terminal emulator itself (`kitty` or `ghostty`) is **not** in the `Brewfile` — it's installed by the
brew-bundle bootstrap script based on the `terminal` answer from `chezmoi init`. switching terminals means
re-running `chezmoi init` (so the saved choice changes) then `chezmoi apply`. the previous terminal is not
uninstalled automatically (`brew uninstall --cask kitty` to remove it).

to capture packages installed by hand:

```sh
cd "$(chezmoi source-path)/.."
brew bundle dump --force     # overwrite Brewfile from current machine state
brew bundle check            # what's in Brewfile but missing?
```

> `brew bundle dump --force` will re-add the currently installed terminal cask(s) to the `Brewfile`.
> remove the `cask "kitty"`/`cask "ghostty"` line afterward so the terminal stays driven by `terminal`.

## Commit signing

git commit signing is driven by two separate GPG keys configured during `chezmoi init`:

**Personal repos** — uses the `signingkey` answer and rendered into `~/.config/git/config`:
- a non-empty key sets `user.signingkey` and `commit.gpgsign = true`
- a blank answer sets `commit.gpgsign = false`, so commits still work on machines without your key

**Internal/work repos** — uses the `internalsigningkey` answer and rendered into `~/.config/git/ghec.gitconfig` and `~/.config/git/tgt.gitconfig`:
- applies to repos under `~/dev/github.com/target-corp/`, `~/dev/github.com/target-corp-eng/`, `~/dev/github.com/target-corp-test/`, and `~/dev/git.target.com/`
- a non-empty key sets `user.signingkey` and `commit.gpgsign = true` for these repos
- a blank answer disables commit signing on internal repos

on a new machine, import (or create) your keys first, then run `chezmoi init` — the prompt
auto-detects the secret keys whose uids match your git emails:

```sh
gpg --list-secret-keys --keyid-format=long   # confirm the keys are present
chezmoi init                                 # accept the detected keys at the prompts
```

`gnupg` is installed via the [`Brewfile`](Brewfile). if you pull this change onto a machine that was
already set up, re-run `chezmoi init` once so the new `internalsigningkey` value is written to your chezmoi
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
