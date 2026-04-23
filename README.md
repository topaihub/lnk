# lnk — dotfiles sync via Git + symlinks

Sync your dotfiles across machines using Git as storage and symlinks for linking.

## 安装

### 下载预编译二进制

从 [Releases](https://github.com/topaihub/lnk/releases) 页面下载对应平台的可执行文件。

| 平台 | 文件名 |
|------|--------|
| Linux x86_64 | `lnk-linux-x86_64` |
| Linux aarch64 | `lnk-linux-aarch64` |
| macOS Apple Silicon | `lnk-macos-aarch64` |
| macOS Intel | `lnk-macos-x86_64` |
| Windows x86_64 | `lnk-windows-x86_64.exe` |

```bash
# Linux/macOS
chmod +x lnk-linux-x86_64
sudo mv lnk-linux-x86_64 /usr/local/bin/lnk
```

### 从源码构建

```bash
git clone https://github.com/topaihub/lnk.git
cd lnk
zig build -Doptimize=ReleaseSmall
# 二进制在 zig-out/bin/lnk
```

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
