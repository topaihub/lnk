# lnk — 设计文档

用 Zig 编写的跨平台 dotfiles 同步工具。通过 symlink + Git 仓库实现配置文件的跨机器同步。

## 核心概念

```
本地配置文件 ──move──→ Git 仓库目录 ──symlink──→ 原始位置
                            │
                        git push
                            │
                      GitHub/GitLab
                            │
                        git pull
                            │
另一台机器的仓库目录 ──symlink──→ 原始位置
```

用户提供一个 GitHub/GitLab 仓库 URL + token，lnk 负责：
1. 把配置文件移到本地仓库目录
2. 在原位创建 symlink
3. 自动 commit + push 到远程
4. 在新机器上 clone + 重建所有 symlink

## 命令设计

| 命令 | 功能 | 示例 |
|------|------|------|
| `lnk init <repo-url>` | 初始化：clone 仓库到 `~/.lnk/`，创建 SQLite DB | `lnk init https://github.com/user/dotfiles.git` |
| `lnk add <path>` | 添加配置文件：移动到仓库 + 创建 symlink + commit + push | `lnk add ~/.config/fish/config.fish` |
| `lnk remove <name>` | 移除：恢复文件到原位 + 删除 symlink + commit + push | `lnk remove config.fish` |
| `lnk list` | 列出所有跟踪的配置文件及状态 | `lnk list` |
| `lnk restore` | 新机器恢复：pull 仓库 + 重建所有 symlink | `lnk restore` |
| `lnk sync` | 手动同步：pull + push | `lnk sync` |
| `lnk status` | 检查各文件的 symlink 状态和 Git 同步状态 | `lnk status` |

## 数据存储

SQLite 数据库存放在 `~/.lnk/lnk.db`。

```sql
CREATE TABLE entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    original_path TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'file',  -- file | directory
    status TEXT NOT NULL DEFAULT 'linked',  -- linked | unlinked | deleted
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- 存储: repo_url, token, remote_name 等
```

## 目录结构

```
~/.lnk/
├── lnk.db          # SQLite 数据库
└── repo/            # Git 仓库 clone 目录
    ├── .git/
    ├── config.fish   # 被管理的配置文件
    ├── starship.toml
    └── ...
```

## 架构 — 基于 zig-framework

```
src/
├── main.zig                 # 入口，注册命令
├── commands/
│   ├── init.zig             # lnk init
│   ├── add.zig              # lnk add
│   ├── remove.zig           # lnk remove
│   ├── list.zig             # lnk list
│   ├── restore.zig          # lnk restore
│   ├── sync.zig             # lnk sync
│   └── status.zig           # lnk status
├── core/
│   ├── db.zig               # SQLite 操作层
│   ├── linker.zig           # symlink 创建/删除/检查
│   └── git.zig              # Git 操作（调用系统 git）
└── platform/
    └── paths.zig            # 跨平台路径（~/.lnk/ 等）
```

### 框架模块使用

| 框架模块 | 用途 |
|----------|------|
| `app/CommandDispatcher` | CLI 命令注册和分发 |
| `effects/fs.zig` | 文件移动、目录创建、读写（需扩展 symlink） |
| `effects/process_runner.zig` | 执行 git clone/add/commit/push |
| `effects/env_provider.zig` | 读取 HOME 等环境变量 |
| `config/` | 存储仓库 URL、token 等配置 |
| `core/logging/` | 操作日志输出 |
| `core/validation/` | 参数校验 |

### 需要扩展 zig-framework

`effects/fs.zig` 的 FileSystem 接口需要新增：
- `createSymlink(target, link_path)` — 创建符号链接
- `readLink(path) -> []u8` — 读取符号链接目标
- `isSymlink(path) -> bool` — 判断是否为符号链接

这些在 Zig `std.fs` 中都有原生支持（`symLinkAbsolute`、`readLinkAbsolute`）。

## Git 操作流程

### init
```
1. 用 token 构造认证 URL: https://<token>@github.com/user/repo.git
2. git clone <url> ~/.lnk/repo/
3. 创建 SQLite DB
4. 扫描仓库中已有文件，录入 DB（status = unlinked）
```

### add
```
1. 检查源文件存在且不是 symlink
2. 移动文件到 ~/.lnk/repo/<name>
3. 在原位创建 symlink → ~/.lnk/repo/<name>
4. 录入 DB（status = linked）
5. git add + git commit + git push
```

### restore（新机器）
```
1. git pull
2. 遍历 DB 中所有 entries
3. 对每个 entry：在 original_path 创建 symlink → repo 中的文件
4. 更新 DB status = linked
```

## 跨平台支持

| 平台 | HOME 路径 | 备注 |
|------|-----------|------|
| Linux/WSL | `$HOME` | 主要目标平台 |
| macOS | `$HOME` | 完全兼容 |
| Windows | `%USERPROFILE%` | symlink 需要开发者模式或管理员权限 |

## 安全考虑

- Token 存储在本地 SQLite 的 config 表中，文件权限设为 600
- 支持 `LNK_TOKEN` 环境变量覆盖，避免 token 持久化
- `.gitignore` 中不自动排除任何文件，用户自行决定哪些文件推到仓库

## 编译产物

单个静态二进制，零运行时依赖（SQLite 编译进去）。通过 Zig 交叉编译一次产出：
- `lnk-linux-x86_64`
- `lnk-linux-aarch64`
- `lnk-macos-x86_64`
- `lnk-macos-aarch64`
- `lnk-windows-x86_64.exe`
