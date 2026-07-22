# plyr4/terminal

Personal macOS (and lightly Linux) dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## how it works (read this first)

The repo is the single source of truth. Stow symlinks every file under
[`stow/`](stow/) into your home directory, so `~/.zaliases` *is* a symlink to
`stow/zsh/.zaliases` — the same file on disk:

```sh
ls -l ~/.zaliases
# ~/.zaliases -> .../terminal/stow/zsh/.zaliases
```

- **Editing `~/.zaliases` or `stow/zsh/.zaliases` is the same edit** — there is nothing to copy or "sync". The change is live in a new shell right away and is already in the repo's working tree; you just `git commit` it.
- **`sync.sh` is for Homebrew packages, not dotfiles.** Dotfiles never need syncing — the symlink *is* the sync.
- **Secrets are the exception:** `~/.zsensitive` is a real file (not a symlink), git-ignored, and never committed.

## everyday workflows

Run `git` from the repo: `cd ~/dev/github.com/plyr4/terminal`.

**Add or change an alias, function, env var, or the prompt**

```sh
vim ~/.zaliases       # aliases/functions   (env, PATH, and prompt live in ~/.zprofile)
git add -A && git commit -m "zsh: add my-alias"
```

Bash equivalents are `~/.bash_aliases` and `~/.bash_profile`.

**Add a work-only alias or env var** — edit `~/.config/zsh/internal.zsh` (the git-ignored work overlay) and commit it inside `vader-terminal-internal/`, never in the public repo.

**Add a secret** (token, password):

```sh
echo 'export GITHUB_TOKEN=...' >> ~/.zsensitive   # real file, never committed
```

**I just ran `brew install <pkg>`** — capture it so a new laptop gets it too:

```sh
./sync.sh             # shows what is installed but not tracked in the Brewfile
```

**Check everything is linked and healthy:**

```sh
./validate.sh
```

## where things live

Every path below is a symlink into the repo — edit it directly, then commit.

| to change…                      | edit                                                             |
| ------------------------------- | ---------------------------------------------------------------- |
| personal aliases / functions    | `~/.zaliases`                                                    |
| env vars, `PATH`, prompt        | `~/.zprofile`                                                    |
| zsh startup (plugins, drop-ins) | `~/.zshrc`                                                       |
| bash                            | `~/.bash_aliases`, `~/.bash_profile`                             |
| git identity + config           | `~/.gitconfig`                                                   |
| ssh hosts                       | `~/.ssh/config`                                                  |
| vim                             | `~/.vimrc`                                                       |
| kitty                           | `~/.config/kitty/kitty.conf`                                     |
| work-only shell config          | `~/.config/zsh/internal.zsh` *(overlay)*                         |
| Homebrew packages               | [`Brewfile`](Brewfile) — capture drift with [`sync.sh`](sync.sh) |
| secrets (never committed)       | `~/.zsensitive`, `~/.bash_local`                                 |

## setup

### new machine

```sh
git clone git@github.com:plyr4/terminal.git ~/dev/github.com/plyr4/terminal
cd ~/dev/github.com/plyr4/terminal
./install.sh            # OS prerequisites (Homebrew + Brewfile) and stow everything
./bootstrap/neovim.sh   # optional: neovim config
exec zsh                # restart your shell
```

`install.sh` detects the OS, runs the matching bootstrap script, then links every package. If the xcode command line tools launch a GUI installer, re-run `./install.sh` once it finishes.

### existing machine (already has real dotfiles)

`migrate.sh` moves any colliding file into `~/.dotfiles-backup/<timestamp>/`, then links the packages. It is safe to re-run and skips files that are already linked.

```sh
cd ~/dev/github.com/plyr4/terminal
./migrate.sh            # preview first with --dry-run; --no-internal skips the work overlay
./validate.sh           # confirm everything is linked and wired
exec zsh
```

Roll back by moving a file from the backup directory back into `~`.

## keeping packages in sync (drift over time)

The [`Brewfile`](Brewfile) (installed with `brew bundle`) is the source of truth for packages. Over time you `brew install` things by hand; [`sync.sh`](sync.sh) keeps the repo aware of that drift. zsh plugins are Homebrew packages, so they are captured too.

```sh
# read-only: what is installed but not in the Brewfile (and vice versa)
./sync.sh

# add the formulae/casks you want to keep to the Brewfile, then commit
git add Brewfile && git commit -m "brew: track <pkg>"
```

**Before switching laptops** — snapshot the whole machine at once:

```sh
./sync.sh --dump        # backs up the old Brewfile first; review with git diff
```

`--dump` replaces the curated file with a full `brew bundle dump`
run `git checkout Brewfile` to revert if you prefer to keep the curated list.

Work taps and packages must not land in this public repo. `--dump` flags anything private-looking (non-default taps, `git@` URLs) so you can scrub it, or dump straight into the git-ignored overlay:

```sh
./sync.sh --dump --file vader-terminal-internal/Brewfile
```

## linux

```sh
./bootstrap/linux.sh   # apt packages, go, docker
./bootstrap/stow.sh    # symlink the packages
```

Linux support is intentionally minimal and isolated in `bootstrap/linux.sh`.
Override the Go version with `GO_VERSION=1.22.5 ./bootstrap/linux.sh`.

## working with stow

All commands run from the repo root.

```sh
# link (or re-link) a package
stow --no-folding --restow --dir stow --target ~ zsh

# link everything at once
./bootstrap/stow.sh

# remove a package's symlinks
stow --dir stow --target ~ --delete zsh
```

`--no-folding` links individual files instead of turning a whole directory into a symlink, which keeps `~/.ssh` private and lets the private overlay (below) drop files into the same directories.

### adding a new package

1. Create `stow/<name>/` with files laid out relative to `$HOME`
   (e.g. `stow/foo/.config/foo/foo.conf` → `~/.config/foo/foo.conf`).
2. Add `<name>` to the `packages` array in [`bootstrap/stow.sh`](bootstrap/stow.sh).
3. Run `./bootstrap/stow.sh`.

## neovim

The Neovim config is a standalone git repo (an AstroNvim fork), so it is managed by [`bootstrap/neovim.sh`](bootstrap/neovim.sh) rather than Stow. It backs up any existing `~/.config/nvim` and clones the fork. Point it elsewhere with `NVIM_CONFIG_REPO=... ./bootstrap/neovim.sh`.

## kitty

`brew bundle` installs the kitty app; the package provides a minimal [`kitty.conf`](stow/kitty/.config/kitty/kitty.conf). On Linux install kitty from the [official binary](https://sw.kovidgoyal.net/kitty/binary/).

## secrets and local overrides

Nothing secret lives in this repo. Machine-local secrets go in files that are git-ignored and sourced only if present:

- `~/.zsensitive` — sourced by `~/.zshrc` (zsh)
- `~/.bash_local` — sourced by `~/.bash_profile` (bash)

```sh
echo 'export GITHUB_TOKEN=...' >> ~/.zsensitive
```

## private / work overlay

Work-specific configuration is isolated in `vader-terminal-internal/` (git-ignored) and layered on top of the public base through optional include hooks:

- `~/.gitconfig` includes `~/.config/git/internal.gitconfig` if it exists
- `~/.ssh/config` includes `~/.ssh/config.d/*.conf`
- `~/.zshrc` sources `~/.config/zsh/*.zsh`

Because each hook tolerates missing files, the base repo works standalone. See `vader-terminal-internal/README.md` for details and how to split it into its own repository later.

## license

[MIT](LICENSE)
