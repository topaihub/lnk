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
            const stderr = std.fs.File.stderr().deprecatedWriter();
            stderr.print("Error: {}\n", .{err}) catch {};
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        const stdout = std.fs.File.stdout().deprecatedWriter();
        try stdout.print("lnk v0.1.0\n", .{});
    } else {
        const stderr = std.fs.File.stderr().deprecatedWriter();
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
