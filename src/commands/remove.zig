const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    if (args.len < 1) {
        try stdout.print("Usage: lnk remove <name>\n", .{});
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
        try stdout.print("Error: '{s}' not found in tracked files\n", .{name});
        return error.FileNotFound;
    }

    const repo_file = try std.fs.path.join(allocator, &.{ repo_dir, name });
    defer allocator.free(repo_file);

    if (linker.isSymlink(original_path.?)) {
        try linker.removeSymlink(original_path.?);
    }
    std.fs.cwd().copyFile(repo_file, std.fs.cwd(), original_path.?, .{}) catch {};
    std.fs.cwd().deleteFile(repo_file) catch {};

    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);
    try database.deleteEntry(name_z);

    // Read auth from DB
    const repo_url = try database.getConfig(allocator, "repo_url");
    defer if (repo_url) |u| allocator.free(u);
    const token = try database.getConfig(allocator, "token");
    defer if (token) |t| allocator.free(t);

    const add_out = try git.addAll(allocator, repo_dir);
    allocator.free(add_out);
    const msg = try std.fmt.allocPrint(allocator, "remove: {s}", .{name});
    defer allocator.free(msg);
    const commit_out = git.commit(allocator, repo_dir, msg) catch null;
    if (commit_out) |o| allocator.free(o);
    if (repo_url) |u| {
        git.pushWithAuth(allocator, repo_dir, u, token) catch {};
    }

    try stdout.print("✓ Removed {s}, restored to {s}\n", .{ name, original_path.? });
}
