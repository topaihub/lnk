# lnk — dotfiles sync via Git + symlinks

Sync your dotfiles across machines using Git as storage and symlinks for linking.

## Quick Start

```bash
# Build
zig build

# Initialize with a Git repo
lnk init https://github.com/user/dotfiles.git
lnk init https://github.com/user/dotfiles.git --token <pat>

# Track a config file
lnk add ~/.bashrc
lnk add ~/.config/nvim/init.lua --name nvim-init

# List tracked files
lnk list

# Check status
lnk status

# Remove a tracked file (restores original)
lnk remove .bashrc

# Restore symlinks on a new machine
lnk restore

# Sync (pull + push)
lnk sync
```

## How It Works

1. `lnk init` clones your dotfiles repo to `~/.lnk/repo/`
2. `lnk add` moves the file into the repo, creates a symlink at the original location, and pushes
3. `lnk sync` pulls remote changes and pushes local ones
4. `lnk restore` recreates symlinks on a fresh machine

## Architecture

The project uses a vtable-based interface pattern:

- **core/** — Interface definitions (Store, Vcs, Fs)
- **infra/** — Concrete implementations (SQLite, Git CLI, POSIX)
- **commands/** — Business logic, depends only on interfaces via `App`
- **main.zig** — Wires implementations and dispatches commands

See [references/RULES.md](references/RULES.md) for details.

## Environment Variables

- `LNK_TOKEN` — Git authentication token (alternative to `--token`)
