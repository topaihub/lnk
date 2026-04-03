const std = @import("std");
const init_cmd = @import("commands/init.zig");
const add_cmd = @import("commands/add.zig");
const list_cmd = @import("commands/list.zig");
const status_cmd = @import("commands/status.zig");
const remove_cmd = @import("commands/remove.zig");
const restore_cmd = @import("commands/restore.zig");
const sync_cmd = @import("commands/sync.zig");

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
    const stdout = std.fs.File.stdout().deprecatedWriter();
    const stderr = std.fs.File.stderr().deprecatedWriter();

    if (std.mem.eql(u8, command, "init")) {
        init_cmd.run(allocator, cmd_args) catch |err| {
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "add")) {
        add_cmd.run(allocator, cmd_args) catch |err| {
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "list")) {
        list_cmd.run(allocator) catch |err| {
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "status")) {
        status_cmd.run(allocator) catch |err| {
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "remove")) {
        remove_cmd.run(allocator, cmd_args) catch |err| {
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "restore")) {
        restore_cmd.run(allocator) catch |err| {
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "sync")) {
        sync_cmd.run(allocator) catch |err| {
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        try stdout.print("lnk v0.1.0\n", .{});
    } else {
        stderr.print("Unknown command: {s}\n", .{command}) catch {};
        printUsage();
    }
}

fn printUsage() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
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
    , .{}) catch {};
}
