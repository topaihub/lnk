# lnk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform dotfiles sync CLI tool in Zig using zig-framework, with Git as the sync backend and SQLite for local state.

**Architecture:** CLI commands registered via zig-framework's CommandDispatcher. Core logic split into three modules: db.zig (SQLite), linker.zig (symlink ops), git.zig (shell out to system git). Platform paths abstracted in paths.zig.

**Tech Stack:** Zig 0.15.2, zig-framework (command dispatch, effects/fs, effects/process_runner, logging), SQLite (C amalgamation compiled in), system git.

---

## File Structure

```
lnk-dev/
├── build.zig
├── build.zig.zon
├── src/
│   ├── main.zig              # Entry point: register commands, dispatch
│   ├── commands/
│   │   ├── init.zig          # lnk init <repo-url>
│   │   ├── add.zig           # lnk add <path>
│   │   ├── remove.zig        # lnk remove <name>
│   │   ├── list.zig          # lnk list
│   │   ├── restore.zig       # lnk restore
│   │   ├── sync.zig          # lnk sync
│   │   └── status.zig        # lnk status
│   ├── core/
│   │   ├── db.zig            # SQLite wrapper: open, addEntry, getEntry, getAllEntries, deleteEntry, getConfig, setConfig
│   │   ├── linker.zig        # createSymlink, removeSymlink, isSymlink, readLink
│   │   └── git.zig           # gitClone, gitAdd, gitCommit, gitPush, gitPull
│   └── platform/
│       └── paths.zig         # getLnkHome, getRepoDir, getDbPath
├── tests/
│   ├── test_db.zig
│   ├── test_linker.zig
│   ├── test_git.zig
│   └── test_paths.zig
└── deps/
    └── sqlite3/              # SQLite amalgamation (sqlite3.c + sqlite3.h)
```

---

### Task 1: Project Scaffolding + Zig Install

**Files:**
- Create: `lnk-dev/build.zig`
- Create: `lnk-dev/build.zig.zon`
- Create: `lnk-dev/src/main.zig`

- [ ] **Step 1: Install Zig 0.15.2**

```bash
curl -L https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar -xJ -C /tmp
sudo mv /tmp/zig-linux-x86_64-0.15.2 /usr/local/zig
sudo ln -sf /usr/local/zig/zig /usr/local/bin/zig
zig version
```

Expected: `0.15.2`

- [ ] **Step 2: Create build.zig.zon with framework dependency**

```zig
// lnk-dev/build.zig.zon
.{
    .name = .lnk,
    .version = "0.1.0",
    .minimum_zig_version = "0.15.2",
    .dependencies = .{
        .framework = .{
            .url = "https://github.com/topaihub/zig-framework/archive/refs/heads/main.tar.gz",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

- [ ] **Step 3: Create build.zig**

```zig
// lnk-dev/build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const framework_dep = b.dependency("framework", .{
        .target = target,
        .optimize = optimize,
    });
    const framework_mod = framework_dep.module("framework");

    const exe = b.addExecutable(.{
        .name = "lnk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("framework", framework_mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run lnk");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("framework", framework_mod);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
```

- [ ] **Step 4: Create minimal main.zig**

```zig
// lnk-dev/src/main.zig
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("lnk v0.1.0\n", .{});
}
```

- [ ] **Step 5: Build and verify**

```bash
cd lnk-dev
zig build run
```

Expected: `lnk v0.1.0`

- [ ] **Step 6: Commit**

```bash
cd lnk-dev && git init && git add -A && git commit -m "feat: project scaffolding"
```

---

### Task 2: Platform Paths Module

**Files:**
- Create: `src/platform/paths.zig`
- Test: `tests/test_paths.zig`

- [ ] **Step 1: Write failing test**

```zig
// tests/test_paths.zig
const std = @import("std");
const paths = @import("../src/platform/paths.zig");

test "getLnkHome returns path ending with .lnk" {
    const home = try paths.getLnkHome(std.testing.allocator);
    defer std.testing.allocator.free(home);
    try std.testing.expect(std.mem.endsWith(u8, home, ".lnk"));
}

test "getRepoDir returns path ending with repo" {
    const repo = try paths.getRepoDir(std.testing.allocator);
    defer std.testing.allocator.free(repo);
    try std.testing.expect(std.mem.endsWith(u8, repo, "repo"));
}

test "getDbPath returns path ending with lnk.db" {
    const db = try paths.getDbPath(std.testing.allocator);
    defer std.testing.allocator.free(db);
    try std.testing.expect(std.mem.endsWith(u8, db, "lnk.db"));
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
zig test tests/test_paths.zig
```

Expected: FAIL — module not found

- [ ] **Step 3: Implement paths.zig**

```zig
// src/platform/paths.zig
const std = @import("std");
const builtin = @import("builtin");

pub fn getHomeDir(allocator: std.mem.Allocator) ![]u8 {
    if (builtin.os.tag == .windows) {
        return std.process.getEnvVarOwned(allocator, "USERPROFILE");
    }
    return std.process.getEnvVarOwned(allocator, "HOME");
}

pub fn getLnkHome(allocator: std.mem.Allocator) ![]u8 {
    const home = try getHomeDir(allocator);
    defer allocator.free(home);
    return std.fs.path.join(allocator, &.{ home, ".lnk" });
}

pub fn getRepoDir(allocator: std.mem.Allocator) ![]u8 {
    const lnk_home = try getLnkHome(allocator);
    defer allocator.free(lnk_home);
    return std.fs.path.join(allocator, &.{ lnk_home, "repo" });
}

pub fn getDbPath(allocator: std.mem.Allocator) ![]u8 {
    const lnk_home = try getLnkHome(allocator);
    defer allocator.free(lnk_home);
    return std.fs.path.join(allocator, &.{ lnk_home, "lnk.db" });
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
zig test tests/test_paths.zig
```

Expected: 3 passed

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: platform paths module"
```

---

### Task 3: SQLite Integration + DB Module

**Files:**
- Create: `deps/sqlite3/sqlite3.c` (download)
- Create: `deps/sqlite3/sqlite3.h` (download)
- Create: `src/core/db.zig`
- Modify: `build.zig` (add C compilation)

- [ ] **Step 1: Download SQLite amalgamation**

```bash
mkdir -p deps/sqlite3
curl -L "https://www.sqlite.org/2025/sqlite-amalgamation-3490100.zip" -o /tmp/sqlite3.zip
unzip -jo /tmp/sqlite3.zip -d deps/sqlite3/ "*/sqlite3.c" "*/sqlite3.h"
rm /tmp/sqlite3.zip
```

- [ ] **Step 2: Update build.zig to compile SQLite**

Add to `build.zig` after `framework_mod` line:

```zig
    // SQLite C compilation
    exe.root_module.addCSourceFile(.{
        .file = b.path("deps/sqlite3/sqlite3.c"),
        .flags = &.{ "-DSQLITE_OMIT_LOAD_EXTENSION", "-DSQLITE_THREADSAFE=0" },
    });
    exe.root_module.addIncludePath(b.path("deps/sqlite3"));
    exe.root_module.link_libc = true;

    // Same for tests
    tests.root_module.addCSourceFile(.{
        .file = b.path("deps/sqlite3/sqlite3.c"),
        .flags = &.{ "-DSQLITE_OMIT_LOAD_EXTENSION", "-DSQLITE_THREADSAFE=0" },
    });
    tests.root_module.addIncludePath(b.path("deps/sqlite3"));
    tests.root_module.link_libc = true;
```

- [ ] **Step 3: Implement db.zig**

```zig
// src/core/db.zig
const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const Db = struct {
    handle: *c.sqlite3,

    pub fn open(path: [*:0]const u8) !Db {
        var handle: ?*c.sqlite3 = null;
        if (c.sqlite3_open(path, &handle) != c.SQLITE_OK) {
            if (handle) |h| c.sqlite3_close(h);
            return error.SqliteOpenFailed;
        }
        var db = Db{ .handle = handle.? };
        try db.exec("PRAGMA journal_mode=WAL;");
        try db.exec(
            \\CREATE TABLE IF NOT EXISTS entries (
            \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  name TEXT UNIQUE NOT NULL,
            \\  original_path TEXT NOT NULL,
            \\  type TEXT NOT NULL DEFAULT 'file',
            \\  status TEXT NOT NULL DEFAULT 'linked',
            \\  created_at TEXT DEFAULT (datetime('now')),
            \\  updated_at TEXT DEFAULT (datetime('now'))
            \\);
            \\CREATE TABLE IF NOT EXISTS config (
            \\  key TEXT PRIMARY KEY,
            \\  value TEXT NOT NULL
            \\);
        );
        return db;
    }

    pub fn close(self: *Db) void {
        _ = c.sqlite3_close(self.handle);
    }

    pub fn exec(self: *Db, sql: [*:0]const u8) !void {
        if (c.sqlite3_exec(self.handle, sql, null, null, null) != c.SQLITE_OK) {
            return error.SqliteExecFailed;
        }
    }

    pub fn setConfig(self: *Db, key: [*:0]const u8, value: [*:0]const u8) !void {
        const sql = "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?);";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt.?, 1, key, -1, null);
        _ = c.sqlite3_bind_text(stmt.?, 2, value, -1, null);
        if (c.sqlite3_step(stmt.?) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    pub fn getConfig(self: *Db, allocator: std.mem.Allocator, key: [*:0]const u8) !?[]u8 {
        const sql = "SELECT value FROM config WHERE key = ?;";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt.?, 1, key, -1, null);
        if (c.sqlite3_step(stmt.?) != c.SQLITE_ROW) return null;
        const raw = c.sqlite3_column_text(stmt.?, 0);
        if (raw == null) return null;
        const len: usize = @intCast(c.sqlite3_column_bytes(stmt.?, 0));
        return try allocator.dupe(u8, raw.?[0..len]);
    }

    pub fn addEntry(self: *Db, name: [*:0]const u8, original_path: [*:0]const u8, entry_type: [*:0]const u8) !void {
        const sql = "INSERT OR IGNORE INTO entries (name, original_path, type) VALUES (?, ?, ?);";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt.?, 1, name, -1, null);
        _ = c.sqlite3_bind_text(stmt.?, 2, original_path, -1, null);
        _ = c.sqlite3_bind_text(stmt.?, 3, entry_type, -1, null);
        if (c.sqlite3_step(stmt.?) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    pub fn deleteEntry(self: *Db, name: [*:0]const u8) !void {
        const sql = "DELETE FROM entries WHERE name = ?;";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt.?, 1, name, -1, null);
        if (c.sqlite3_step(stmt.?) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    pub const Entry = struct {
        name: []const u8,
        original_path: []const u8,
        entry_type: []const u8,
        status: []const u8,
    };

    pub fn getAllEntries(self: *Db, allocator: std.mem.Allocator) ![]Entry {
        const sql = "SELECT name, original_path, type, status FROM entries ORDER BY name;";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        var list = std.ArrayList(Entry).init(allocator);
        while (c.sqlite3_step(stmt.?) == c.SQLITE_ROW) {
            const name_raw = c.sqlite3_column_text(stmt.?, 0);
            const path_raw = c.sqlite3_column_text(stmt.?, 1);
            const type_raw = c.sqlite3_column_text(stmt.?, 2);
            const status_raw = c.sqlite3_column_text(stmt.?, 3);
            try list.append(.{
                .name = try allocator.dupe(u8, std.mem.span(name_raw.?)),
                .original_path = try allocator.dupe(u8, std.mem.span(path_raw.?)),
                .entry_type = try allocator.dupe(u8, std.mem.span(type_raw.?)),
                .status = try allocator.dupe(u8, std.mem.span(status_raw.?)),
            });
        }
        return list.toOwnedSlice();
    }

    pub fn updateStatus(self: *Db, name: [*:0]const u8, status: [*:0]const u8) !void {
        const sql = "UPDATE entries SET status = ?, updated_at = datetime('now') WHERE name = ?;";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt.?, 1, status, -1, null);
        _ = c.sqlite3_bind_text(stmt.?, 2, name, -1, null);
        if (c.sqlite3_step(stmt.?) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }
};
```

- [ ] **Step 4: Verify build compiles**

```bash
zig build
```

Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: SQLite integration and db module"
```

---

### Task 4: Linker Module (Symlink Operations)

**Files:**
- Create: `src/core/linker.zig`

- [ ] **Step 1: Implement linker.zig**

```zig
// src/core/linker.zig
const std = @import("std");
const builtin = @import("builtin");

pub fn createSymlink(target: []const u8, link_path: []const u8) !void {
    if (std.fs.path.dirname(link_path)) |dir| {
        std.fs.cwd().makePath(dir) catch {};
    }
    if (builtin.os.tag == .windows) {
        // Windows: use std.fs symlink (requires dev mode or admin)
        try std.fs.cwd().symLink(target, link_path, .{});
    } else {
        try std.posix.symlinkat(target.ptr, std.fs.cwd().fd, link_path.ptr);
    }
}

pub fn removeSymlink(path: []const u8) !void {
    try std.fs.cwd().deleteFile(path);
}

pub fn isSymlink(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    _ = stat;
    // Use lstat to check
    const lstat = std.fs.cwd().statFile(path) catch return false;
    _ = lstat;
    // Simpler: try readLink, if it succeeds it's a symlink
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = std.fs.cwd().readLink(path, &buf) catch return false;
    return true;
}

pub fn readLink(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const target = try std.fs.cwd().readLink(path, &buf);
    return try allocator.dupe(u8, target);
}
```

- [ ] **Step 2: Verify build**

```bash
zig build
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: linker module for symlink operations"
```

---

### Task 5: Git Module

**Files:**
- Create: `src/core/git.zig`

- [ ] **Step 1: Implement git.zig**

```zig
// src/core/git.zig
const std = @import("std");

fn runGit(allocator: std.mem.Allocator, cwd: []const u8, args: []const []const u8) ![]u8 {
    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();
    try argv.append("git");
    try argv.appendSlice(args);

    var child = std.process.Child.init(argv.items, allocator);
    child.cwd = cwd;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    const result = try child.wait();
    const stdout = try result.stdout.reader().readAllAlloc(allocator, 1024 * 1024);

    if (result.term.Exited != 0) {
        allocator.free(stdout);
        return error.GitCommandFailed;
    }
    return stdout;
}

pub fn clone(allocator: std.mem.Allocator, url: []const u8, dest: []const u8) !void {
    const result = try runGit(allocator, ".", &.{ "clone", url, dest });
    allocator.free(result);
}

pub fn addAll(allocator: std.mem.Allocator, repo_dir: []const u8) !void {
    const result = try runGit(allocator, repo_dir, &.{ "add", "-A" });
    allocator.free(result);
}

pub fn commit(allocator: std.mem.Allocator, repo_dir: []const u8, message: []const u8) !void {
    const result = try runGit(allocator, repo_dir, &.{ "commit", "-m", message });
    allocator.free(result);
}

pub fn push(allocator: std.mem.Allocator, repo_dir: []const u8) !void {
    const result = try runGit(allocator, repo_dir, &.{ "push" });
    allocator.free(result);
}

pub fn pull(allocator: std.mem.Allocator, repo_dir: []const u8) !void {
    const result = try runGit(allocator, repo_dir, &.{ "pull" });
    allocator.free(result);
}
```

Note: `runGit` uses `std.process.Child`. The exact API may need adjustment based on Zig 0.15.2's `std.process.Child` — check `std.process.Child.init` signature and `wait()` return type during implementation. The pattern is: spawn child process, capture stdout/stderr, check exit code.

- [ ] **Step 2: Verify build**

```bash
zig build
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: git module for clone/add/commit/push/pull"
```

---

### Task 6: CLI Entry Point + init Command

**Files:**
- Create: `src/commands/init.zig`
- Modify: `src/main.zig`

- [ ] **Step 1: Implement init command**

```zig
// src/commands/init.zig
const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: lnk init <repo-url> [--token <token>]\n", .{});
        return error.MissingArgument;
    }
    const repo_url = args[0];

    // Parse optional --token
    var token: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--token") and i + 1 < args.len) {
            token = args[i + 1];
            i += 1;
        }
    }
    // Also check env var
    if (token == null) {
        token = std.process.getEnvVarOwned(allocator, "LNK_TOKEN") catch null;
    }

    const lnk_home = try paths.getLnkHome(allocator);
    defer allocator.free(lnk_home);
    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);

    // Create ~/.lnk/
    try std.fs.cwd().makePath(lnk_home);

    // Build auth URL if token provided
    var clone_url_buf: [2048]u8 = undefined;
    var clone_url: []const u8 = repo_url;
    if (token) |t| {
        // https://github.com/user/repo.git -> https://<token>@github.com/user/repo.git
        if (std.mem.startsWith(u8, repo_url, "https://")) {
            const rest = repo_url["https://".len..];
            const len = (std.fmt.bufPrint(&clone_url_buf, "https://{s}@{s}", .{ t, rest }) catch return error.UrlTooLong).len;
            clone_url = clone_url_buf[0..len];
        }
    }

    // Clone repo
    std.debug.print("Cloning {s} ...\n", .{repo_url});
    try git.clone(allocator, clone_url, repo_dir);

    // Init DB
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);
    var database = try db.Db.open(db_path_z);
    defer database.close();

    const repo_url_z = try allocator.dupeZ(u8, repo_url);
    defer allocator.free(repo_url_z);
    try database.setConfig("repo_url", repo_url_z);

    if (token) |t| {
        const token_z = try allocator.dupeZ(u8, t);
        defer allocator.free(token_z);
        try database.setConfig("token", token_z);
    }

    // Set DB file permissions to 600
    const lnk_home_z = try allocator.dupeZ(u8, lnk_home);
    defer allocator.free(lnk_home_z);
    std.posix.fchmodat(std.fs.cwd().fd, db_path_z, 0o600, 0) catch {};

    std.debug.print("✓ Initialized lnk at {s}\n", .{lnk_home});
}
```

- [ ] **Step 2: Rewrite main.zig with CLI dispatch**

```zig
// src/main.zig
const std = @import("std");
const init_cmd = @import("commands/init.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];
    const cmd_args = args[2..];

    if (std.mem.eql(u8, command, "init")) {
        init_cmd.run(allocator, cmd_args) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        std.debug.print("lnk v0.1.0\n", .{});
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\lnk — dotfiles sync via Git + symlinks
        \\
        \\Usage: lnk <command> [args]
        \\
        \\Commands:
        \\  init <repo-url>    Clone repo and initialize lnk
        \\  add <path>         Add a config file to sync
        \\  remove <name>      Remove a tracked file
        \\  list               List tracked files
        \\  restore            Restore symlinks on new machine
        \\  sync               Pull + push changes
        \\  status             Show sync status
        \\
    , .{});
}
```

- [ ] **Step 3: Build and test help output**

```bash
zig build run
```

Expected: usage help text

```bash
zig build run -- --version
```

Expected: `lnk v0.1.0`

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: CLI entry point and init command"
```

---

### Task 7: add Command

**Files:**
- Create: `src/commands/add.zig`
- Modify: `src/main.zig` (add dispatch)

- [ ] **Step 1: Implement add command**

```zig
// src/commands/add.zig
const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: lnk add <path> [--name <name>]\n", .{});
        return error.MissingArgument;
    }
    const source_path = args[0];

    // Parse optional --name
    var custom_name: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--name") and i + 1 < args.len) {
            custom_name = args[i + 1];
            i += 1;
        }
    }

    // Resolve absolute path
    const abs_path = try std.fs.cwd().realpathAlloc(allocator, source_path);
    defer allocator.free(abs_path);

    // Check not already a symlink
    if (linker.isSymlink(abs_path)) {
        std.debug.print("Error: {s} is already a symlink\n", .{abs_path});
        return error.AlreadySymlink;
    }

    // Determine name
    const name = custom_name orelse std.fs.path.basename(abs_path);

    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);

    // Destination in repo
    const dest = try std.fs.path.join(allocator, &.{ repo_dir, name });
    defer allocator.free(dest);

    // Move file to repo
    std.fs.cwd().rename(abs_path, dest) catch {
        // Cross-device: copy + delete
        try std.fs.cwd().copyFile(abs_path, std.fs.cwd(), dest, .{});
        try std.fs.cwd().deleteFile(abs_path);
    };

    // Create symlink at original location
    try linker.createSymlink(dest, abs_path);

    // Record in DB
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);
    var database = try db.Db.open(db_path_z);
    defer database.close();

    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);
    const abs_path_z = try allocator.dupeZ(u8, abs_path);
    defer allocator.free(abs_path_z);
    try database.addEntry(name_z, abs_path_z, "file");

    // Git commit + push
    try git.addAll(allocator, repo_dir);
    const msg = try std.fmt.allocPrint(allocator, "add: {s}", .{name});
    defer allocator.free(msg);
    try git.commit(allocator, repo_dir, msg);
    git.push(allocator, repo_dir) catch |err| {
        std.debug.print("Warning: push failed ({}) — changes committed locally\n", .{err});
    };

    std.debug.print("✓ Added {s} → {s}\n", .{ abs_path, dest });
}
```

- [ ] **Step 2: Add dispatch in main.zig**

Add to the command dispatch block in `main.zig`:

```zig
    } else if (std.mem.eql(u8, command, "add")) {
        add_cmd.run(allocator, cmd_args) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            std.process.exit(1);
        };
```

And add import: `const add_cmd = @import("commands/add.zig");`

- [ ] **Step 3: Build**

```bash
zig build
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add command"
```

---

### Task 8: list + status Commands

**Files:**
- Create: `src/commands/list.zig`
- Create: `src/commands/status.zig`
- Modify: `src/main.zig`

- [ ] **Step 1: Implement list command**

```zig
// src/commands/list.zig
const std = @import("std");
const db = @import("../core/db.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    var database = try db.Db.open(db_path_z);
    defer database.close();

    const entries = try database.getAllEntries(allocator);
    defer {
        for (entries) |e| {
            allocator.free(e.name);
            allocator.free(e.original_path);
            allocator.free(e.entry_type);
            allocator.free(e.status);
        }
        allocator.free(entries);
    }

    if (entries.len == 0) {
        std.debug.print("No tracked files. Use 'lnk add <path>' to start.\n", .{});
        return;
    }

    std.debug.print("{s:<20} {s:<40} {s:<10}\n", .{ "NAME", "ORIGINAL PATH", "STATUS" });
    std.debug.print("{s:─<20} {s:─<40} {s:─<10}\n", .{ "", "", "" });
    for (entries) |e| {
        std.debug.print("{s:<20} {s:<40} {s:<10}\n", .{ e.name, e.original_path, e.status });
    }
}
```

- [ ] **Step 2: Implement status command**

```zig
// src/commands/status.zig
const std = @import("std");
const db = @import("../core/db.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);
    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    var database = try db.Db.open(db_path_z);
    defer database.close();

    const entries = try database.getAllEntries(allocator);
    defer {
        for (entries) |e| {
            allocator.free(e.name);
            allocator.free(e.original_path);
            allocator.free(e.entry_type);
            allocator.free(e.status);
        }
        allocator.free(entries);
    }

    if (entries.len == 0) {
        std.debug.print("No tracked files.\n", .{});
        return;
    }

    for (entries) |e| {
        const repo_path = try std.fs.path.join(allocator, &.{ repo_dir, e.name });
        defer allocator.free(repo_path);

        const in_repo = blk: {
            std.fs.cwd().access(repo_path, .{}) catch break :blk false;
            break :blk true;
        };
        const is_linked = linker.isSymlink(e.original_path);

        const icon: []const u8 = if (in_repo and is_linked) "✓" else if (in_repo) "⚠" else "✗";
        std.debug.print("{s} {s:<20} {s}\n", .{ icon, e.name, e.original_path });
    }
}
```

- [ ] **Step 3: Add dispatch in main.zig**

Add imports and dispatch cases for `list` and `status`:

```zig
const list_cmd = @import("commands/list.zig");
const status_cmd = @import("commands/status.zig");

// In dispatch:
    } else if (std.mem.eql(u8, command, "list")) {
        list_cmd.run(allocator) catch |err| { ... };
    } else if (std.mem.eql(u8, command, "status")) {
        status_cmd.run(allocator) catch |err| { ... };
```

- [ ] **Step 4: Build**

```bash
zig build
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: list and status commands"
```

---

### Task 9: remove Command

**Files:**
- Create: `src/commands/remove.zig`
- Modify: `src/main.zig`

- [ ] **Step 1: Implement remove command**

```zig
// src/commands/remove.zig
const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: lnk remove <name>\n", .{});
        return error.MissingArgument;
    }
    const name = args[0];

    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    var database = try db.Db.open(db_path_z);
    defer database.close();

    // Get entry to find original_path
    const entries = try database.getAllEntries(allocator);
    defer {
        for (entries) |e| {
            allocator.free(e.name);
            allocator.free(e.original_path);
            allocator.free(e.entry_type);
            allocator.free(e.status);
        }
        allocator.free(entries);
    }

    var original_path: ?[]const u8 = null;
    for (entries) |e| {
        if (std.mem.eql(u8, e.name, name)) {
            original_path = e.original_path;
            break;
        }
    }
    if (original_path == null) {
        std.debug.print("Error: '{s}' not found in tracked files\n", .{name});
        return error.EntryNotFound;
    }

    const repo_file = try std.fs.path.join(allocator, &.{ repo_dir, name });
    defer allocator.free(repo_file);

    // Remove symlink at original location
    if (linker.isSymlink(original_path.?)) {
        try linker.removeSymlink(original_path.?);
    }

    // Copy file back from repo to original location
    std.fs.cwd().copyFile(repo_file, std.fs.cwd(), original_path.?, .{}) catch {};

    // Delete from repo
    std.fs.cwd().deleteFile(repo_file) catch {};

    // Delete from DB
    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);
    try database.deleteEntry(name_z);

    // Git commit + push
    try git.addAll(allocator, repo_dir);
    const msg = try std.fmt.allocPrint(allocator, "remove: {s}", .{name});
    defer allocator.free(msg);
    git.commit(allocator, repo_dir, msg) catch {};
    git.push(allocator, repo_dir) catch {};

    std.debug.print("✓ Removed {s}, restored to {s}\n", .{ name, original_path.? });
}
```

- [ ] **Step 2: Add dispatch in main.zig**

```zig
const remove_cmd = @import("commands/remove.zig");

    } else if (std.mem.eql(u8, command, "remove")) {
        remove_cmd.run(allocator, cmd_args) catch |err| { ... };
```

- [ ] **Step 3: Build**

```bash
zig build
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: remove command"
```

---

### Task 10: restore + sync Commands

**Files:**
- Create: `src/commands/restore.zig`
- Create: `src/commands/sync.zig`
- Modify: `src/main.zig`

- [ ] **Step 1: Implement restore command**

```zig
// src/commands/restore.zig
const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    // Pull latest
    std.debug.print("Pulling latest changes...\n", .{});
    git.pull(allocator, repo_dir) catch |err| {
        std.debug.print("Warning: pull failed ({})\n", .{err});
    };

    var database = try db.Db.open(db_path_z);
    defer database.close();

    const entries = try database.getAllEntries(allocator);
    defer {
        for (entries) |e| {
            allocator.free(e.name);
            allocator.free(e.original_path);
            allocator.free(e.entry_type);
            allocator.free(e.status);
        }
        allocator.free(entries);
    }

    var restored: usize = 0;
    for (entries) |e| {
        const repo_file = try std.fs.path.join(allocator, &.{ repo_dir, e.name });
        defer allocator.free(repo_file);

        // Skip if already correctly linked
        if (linker.isSymlink(e.original_path)) {
            const target = linker.readLink(allocator, e.original_path) catch continue;
            defer allocator.free(target);
            if (std.mem.eql(u8, target, repo_file)) continue;
            // Wrong target, remove and relink
            linker.removeSymlink(e.original_path) catch {};
        }

        // Remove existing file at original path if present
        std.fs.cwd().deleteFile(e.original_path) catch {};

        linker.createSymlink(repo_file, e.original_path) catch |err| {
            std.debug.print("  ✗ {s}: {}\n", .{ e.name, err });
            continue;
        };

        const name_z = try allocator.dupeZ(u8, e.name);
        defer allocator.free(name_z);
        database.updateStatus(name_z, "linked") catch {};

        std.debug.print("  ✓ {s} → {s}\n", .{ e.name, e.original_path });
        restored += 1;
    }

    std.debug.print("\nRestored {d}/{d} entries.\n", .{ restored, entries.len });
}
```

- [ ] **Step 2: Implement sync command**

```zig
// src/commands/sync.zig
const std = @import("std");
const git = @import("../core/git.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);

    std.debug.print("Pulling...\n", .{});
    git.pull(allocator, repo_dir) catch |err| {
        std.debug.print("Pull failed: {}\n", .{err});
    };

    std.debug.print("Pushing...\n", .{});
    try git.addAll(allocator, repo_dir);
    git.commit(allocator, repo_dir, "sync") catch {};
    git.push(allocator, repo_dir) catch |err| {
        std.debug.print("Push failed: {}\n", .{err});
    };

    std.debug.print("✓ Sync complete.\n", .{});
}
```

- [ ] **Step 3: Add dispatch in main.zig**

```zig
const restore_cmd = @import("commands/restore.zig");
const sync_cmd = @import("commands/sync.zig");

    } else if (std.mem.eql(u8, command, "restore")) {
        restore_cmd.run(allocator) catch |err| { ... };
    } else if (std.mem.eql(u8, command, "sync")) {
        sync_cmd.run(allocator) catch |err| { ... };
```

- [ ] **Step 4: Build**

```bash
zig build
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: restore and sync commands"
```

---

### Task 11: End-to-End Manual Test

- [ ] **Step 1: Create a test Git repo on GitHub**

Create a private repo (e.g., `dotfiles-test`) on GitHub.

- [ ] **Step 2: Test full workflow**

```bash
# Init
zig build
./zig-out/bin/lnk init https://github.com/<user>/dotfiles-test.git --token <token>

# Create a test config file
echo "test config" > /tmp/test-config.txt

# Add
./zig-out/bin/lnk add /tmp/test-config.txt

# List
./zig-out/bin/lnk list

# Status
./zig-out/bin/lnk status

# Verify symlink
ls -la /tmp/test-config.txt  # should show symlink

# Sync
./zig-out/bin/lnk sync

# Remove
./zig-out/bin/lnk remove test-config.txt

# Verify file restored
cat /tmp/test-config.txt  # should show "test config"
```

- [ ] **Step 3: Fix any issues found**

- [ ] **Step 4: Final commit**

```bash
git add -A && git commit -m "chore: end-to-end verification complete"
```
