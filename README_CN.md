中文 | [English](README.md)

# lnk — 通过 Git + 符号链接同步 dotfiles

使用 Git 作为存储、符号链接进行关联，在多台机器间同步你的 dotfiles。

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

## 快速开始

```bash
# 构建
zig build

# 使用 Git 仓库初始化
lnk init https://github.com/user/dotfiles.git
lnk init https://github.com/user/dotfiles.git --token <pat>

# 追踪配置文件
lnk add ~/.bashrc
lnk add ~/.config/nvim/init.lua --name nvim-init

# 列出已追踪的文件
lnk list

# 检查状态
lnk status

# 移除已追踪的文件（恢复原始文件）
lnk remove .bashrc

# 在新机器上恢复符号链接
lnk restore

# 同步（拉取 + 推送）
lnk sync
```

## 工作原理

1. `lnk init` 将你的 dotfiles 仓库克隆到 `~/.lnk/repo/`
2. `lnk add` 将文件移入仓库，在原始位置创建符号链接，并推送
3. `lnk sync` 拉取远程更改并推送本地更改
4. `lnk restore` 在新机器上重新创建符号链接

## 架构

项目使用基于 vtable 的接口模式：

- **core/** — 接口定义（Store、Vcs、Fs）
- **infra/** — 具体实现（SQLite、Git CLI、POSIX）
- **commands/** — 业务逻辑，仅通过 `App` 依赖接口
- **main.zig** — 组装实现并分发命令

详见 [references/RULES.md](references/RULES.md)。

## 环境变量

- `LNK_TOKEN` — Git 认证令牌（`--token` 的替代方式）
