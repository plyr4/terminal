# plyr4/terminal

Personal laptop dotfiles managed with [chezmoi](https://www.chezmoi.io).

chezmoi renders the files under [`home/`](home) into `$HOME`. The repo is the
single source of truth: edit the source, run `chezmoi apply`, and the change is
live. An optional, git-ignored **work profile** layers private configuration on
top without ever touching a personal machine.

## install

Fresh machine (installs chezmoi, clones this repo, applies everything):

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply plyr4/terminal
```

Already have Homebrew?

```sh
brew install chezmoi
chezmoi init --apply plyr4/terminal
```

`init` asks two questions and remembers the answers in
`~/.config/chezmoi/chezmoi.toml`:

- **Is this a work machine?** — enables the work profile (default: no)
- **Manage the neovim config?** — clones the AstroNvim fork into
  `~/.config/nvim` (default: yes)

`apply` then writes the dotfiles and runs the bootstrap scripts:

1. install system packages — Xcode CLT + Homebrew on macOS, or apt + Go + Docker
   on Linux (runs once per machine);
2. `brew bundle` from the [`Brewfile`](Brewfile) (re-runs whenever it changes).

Restart your shell (`exec zsh`) when it finishes.

## everyday workflows

chezmoi syncs the source and `$HOME` explicitly:

```sh
chezmoi edit ~/.zshrc     # edit a file's source, then...
chezmoi apply             # ...write it into $HOME

chezmoi diff              # preview pending changes ($HOME vs source)
chezmoi status            # short status of what would change
chezmoi update            # git pull the source and apply in one step
chezmoi doctor            # diagnose a broken setup
```

Changed a file directly in `$HOME`? Pull it back into the source and commit:

```sh
chezmoi re-add                                   # re-import managed files that changed
chezmoi cd                                        # open the source dir
git add -A && git commit -m "zsh: ..." && git push
```

`chezmoi edit`, `chezmoi cd`, and `chezmoi source-path` mean you never need to
remember where the source physically lives (`~/.local/share/chezmoi`).

## adding a new managed file

```sh
chezmoi add ~/.config/foo/foo.conf     # import as-is
chezmoi add --encrypt ~/.some-secret   # import encrypted (see secrets)
```

chezmoi chooses the source name automatically (`dot_`, `private_`,
`executable_`, …). Commit from `chezmoi cd`.

## Homebrew

The [`Brewfile`](Brewfile) is the single source of truth for packages, and
`chezmoi apply` runs `brew bundle` automatically whenever it changes. Capture
packages you installed by hand, then commit:

```sh
cd "$(chezmoi source-path)/.."     # repo root
brew bundle dump --force            # snapshot the machine into ./Brewfile
brew bundle check                   # what's in the Brewfile but not installed?
```

Work-only packages can go in a git-ignored `Brewfile.local` at the repo root,
which `apply` also installs when present.

## work profile

Work configuration (git identities, SSH hosts, proxies, npm registry) is applied
only when `work = true`. It lives in the source tree but is **git-ignored, so it
is never committed to this public repo** — keep it in a private repo.

Enable it:

```sh
chezmoi init                 # answer "yes" to the work-machine prompt, or
chezmoi edit-config          # set  work = true  under [data]
chezmoi apply
```

When enabled, the files below layer onto the base through its built-in extension
points (each tolerates the file being absent, so the base works standalone):

| work file                                           | hooks into                         |
| --------------------------------------------------- | ---------------------------------- |
| `~/.config/git/internal.gitconfig` (+ `tgt`/`ghec`) | `~/.config/git/config` `[include]` |
| `~/.ssh/config.d/target.conf`                       | `~/.ssh/config` `Include`          |
| `~/.config/zsh/internal.zsh`                        | `~/.zshrc` drop-in loop            |
| `~/.npmrc`, `~/.local/bin/post_ghec_webhook.sh`     | —                                  |

On a personal machine `work` stays `false` and none of these are touched.

## secrets

Machine-local secrets never live in the repo:

- `~/.zsensitive` (zsh) and `~/.bash_local` (bash) are sourced if present —
  create them yourself:
  ```sh
  echo 'export GITHUB_TOKEN=...' >> ~/.zsensitive
  ```
- To version-control a secret, use chezmoi's built-in age encryption (only the
  ciphertext is committed):
  ```sh
  age-keygen -o ~/.config/chezmoi/key.txt   # once
  chezmoi edit-config                        # uncomment the [age] block
  chezmoi add --encrypt ~/.zsensitive
  ```
- Or read from a password manager in a template, e.g.
  `{{ onepasswordRead "op://vault/item/field" }}`.

## license

MIT
