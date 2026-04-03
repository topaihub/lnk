# lnk

跨平台 dotfiles 同步工具。通过 Git 仓库 + symlink 实现配置文件的多机器同步。

单个二进制，零依赖（仅需系统 git），支持 Linux / macOS / Windows。

## 安装

### 从 Release 下载

前往 [Releases](https://github.com/topmcp/lnk/releases) 下载对应平台的二进制文件：

```bash
# Linux x86_64
curl -fL -o lnk https://github.com/topmcp/lnk/releases/latest/download/lnk-linux-x86_64
chmod +x lnk
sudo mv lnk /usr/local/bin/

# macOS Apple Silicon
curl -fL -o lnk https://github.com/topmcp/lnk/releases/latest/download/lnk-macos-aarch64
chmod +x lnk
sudo mv lnk /usr/local/bin/
```

Windows 用户下载 `lnk-windows-x86_64.exe`，放到 PATH 目录即可。

### 从源码编译

需要 [Zig 0.15.2](https://ziglang.org/download/)：

```bash
git clone https://github.com/topmcp/lnk.git
cd lnk
zig build -Doptimize=ReleaseSmall
# 二进制在 zig-out/bin/lnk
```

## 快速开始

### 1. 创建一个 GitHub 私有仓库

在 GitHub 上创建一个空的私有仓库（如 `dotfiles`），用于存放配置文件。

### 2. 生成 Personal Access Token

GitHub → Settings → Developer settings → Personal access tokens → 生成一个有 `repo` 权限的 token。

### 3. 初始化

```bash
lnk init https://github.com/你的用户名/dotfiles.git --token ghp_xxxx
```

也可以通过环境变量传 token：

```bash
export LNK_TOKEN=ghp_xxxx
lnk init https://github.com/你的用户名/dotfiles.git
```

### 4. 添加配置文件

```bash
lnk add ~/.config/fish/config.fish
lnk add ~/.config/starship.toml
lnk add ~/.gitconfig
```

每次 `add` 会自动：
- 将文件移到 `~/.lnk/repo/` 目录
- 在原位创建 symlink
- git commit + push 到远程仓库

### 5. 在新机器上恢复

```bash
lnk init https://github.com/你的用户名/dotfiles.git --token ghp_xxxx
lnk restore
```

`restore` 会自动 pull 最新文件并重建所有 symlink。

## 命令参考

| 命令 | 说明 |
|------|------|
| `lnk init <repo-url>` | 初始化：clone 仓库，创建本地数据库 |
| `lnk add <path>` | 添加配置文件到同步 |
| `lnk add <path> --name <name>` | 添加并指定自定义名称 |
| `lnk remove <name>` | 移除跟踪，恢复文件到原位 |
| `lnk list` | 列出所有跟踪的文件 |
| `lnk status` | 查看各文件的 symlink 状态 |
| `lnk restore` | 新机器恢复：pull + 重建所有 symlink |
| `lnk sync` | 手动同步：pull + push |
| `lnk -v` | 显示版本 |

## 工作原理

```
~/.config/fish/config.fish  →  symlink  →  ~/.lnk/repo/config.fish
                                                    │
                                                git push
                                                    │
                                              GitHub 仓库
                                                    │
                                                git pull
                                                    │
新机器 ~/.config/fish/config.fish  ←  symlink  ←  ~/.lnk/repo/config.fish
```

数据存储在 `~/.lnk/` 目录：

```
~/.lnk/
├── lnk.db    # SQLite 数据库（跟踪信息）
└── repo/     # Git 仓库（配置文件实际存放位置）
```

## 常见用法

```bash
# 同步 fish 配置
lnk add ~/.config/fish/config.fish

# 同步 starship 提示符配置
lnk add ~/.config/starship.toml

# 同步 git 配置
lnk add ~/.gitconfig

# 同步 SSH 配置（注意：私钥建议排除）
lnk add ~/.ssh/config

# 查看状态
lnk status

# 手动同步
lnk sync
```

## 平台支持

| 平台 | 架构 | 状态 |
|------|------|------|
| Linux | x86_64 / aarch64 | ✓ |
| macOS | x86_64 / Apple Silicon | ✓ |
| Windows | x86_64 / aarch64 | ✓ |

Windows 上创建 symlink 需要开启开发者模式或以管理员身份运行。

## License

MIT
