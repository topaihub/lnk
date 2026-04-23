const std = @import("std");
const logging = @import("zig-logging");
const App = @import("app.zig").App;
const SqliteStore = @import("infra/sqlite_store.zig").SqliteStore;
const GitVcs = @import("infra/git_vcs.zig").GitVcs;
const PosixFs = @import("infra/posix_fs.zig").PosixFs;
const init_cmd = @import("commands/init.zig");
const add_cmd = @import("commands/add.zig");
const remove_cmd = @import("commands/remove.zig");
const list_cmd = @import("commands/list.zig");
const status_cmd = @import("commands/status.zig");
const restore_cmd = @import("commands/restore.zig");
const sync_cmd = @import("commands/sync.zig");

const CmdFn = union(enum) {
    with_args: *const fn (*App, []const []const u8) anyerror!void,
    no_args: *const fn (*App) anyerror!void,
};

const Command = struct {
    name: []const u8,
    func: CmdFn,
};

const commands_table = [_]Command{
    .{ .name = "init", .func = .{ .with_args = init_cmd.run } },
    .{ .name = "add", .func = .{ .with_args = add_cmd.run } },
    .{ .name = "remove", .func = .{ .with_args = remove_cmd.run } },
    .{ .name = "list", .func = .{ .no_args = list_cmd.run } },
    .{ .name = "status", .func = .{ .no_args = status_cmd.run } },
    .{ .name = "restore", .func = .{ .no_args = restore_cmd.run } },
    .{ .name = "sync", .func = .{ .no_args = sync_cmd.run } },
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // Collect args
    var arg_list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (arg_list.items) |a| allocator.free(a);
        arg_list.deinit(allocator);
    }
    var it = if (@import("builtin").os.tag == .windows)
        try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator)
    else
        std.process.Args.Iterator.init(init.minimal.args);
    while (it.next()) |arg| {
        try arg_list.append(allocator, try allocator.dupe(u8, arg));
    }
    const args = arg_list.items;

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];
    const cmd_args = args[2..];

    if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        std.debug.print("lnk v0.2.0\n", .{});
        return;
    }

    // 初始化日志
    var managed_logger = try logging.create(allocator, .{
        .level = .debug,
        .trace_console = .{},
    });

    // Resolve paths
    const home_env = std.c.getenv("HOME") orelse return error.HomeNotSet;
    const home = std.mem.sliceTo(home_env, 0);
    const lnk_home = try std.fs.path.join(allocator, &.{ home, ".lnk" });
    const repo_dir = try std.fs.path.join(allocator, &.{ home, ".lnk", "repo" });
    const db_path = try std.fs.path.join(allocator, &.{ home, ".lnk", "lnk.db" });
    defer allocator.free(db_path);
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    // Create ~/.lnk/ so DB can be opened
    std.Io.Dir.cwd().createDirPath(io, lnk_home) catch {};

    // Create infra instances
    var sqlite = try SqliteStore.open(db_path_z);
    var git_vcs = GitVcs{ .io = io };
    var posix_fs = PosixFs{ .io = io };

    var app = App{
        .allocator = allocator,
        .io = io,
        .store = sqlite.store(),
        .vcs = git_vcs.vcs(),
        .fs = posix_fs.fs(),
        .lnk_home = lnk_home,
        .repo_dir = repo_dir,
        .log = managed_logger.logger.child("lnk"),
        .managed_logger = managed_logger,
    };
    defer app.deinit();

    // 记录命令执行
    app.log.info("command", &.{
        logging.LogField.string("cmd", command),
    });

    for (commands_table) |cmd| {
        if (std.mem.eql(u8, command, cmd.name)) {
            switch (cmd.func) {
                .with_args => |f| f(&app, cmd_args) catch |err| {
                    app.log.@"error"("command failed", &.{
                        logging.LogField.string("cmd", command),
                    });
                    std.debug.print("Error: {}\n", .{err});
                    std.process.exit(1);
                },
                .no_args => |f| f(&app) catch |err| {
                    app.log.@"error"("command failed", &.{
                        logging.LogField.string("cmd", command),
                    });
                    std.debug.print("Error: {}\n", .{err});
                    std.process.exit(1);
                },
            }
            return;
        }
    }

    std.debug.print("Unknown command: {s}\n", .{command});
    printUsage();
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
