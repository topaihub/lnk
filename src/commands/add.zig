const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    if (args.len < 1) {
        try stdout.print("Usage: lnk add <path> [--name <name>]\n", .{});
        return error.MissingArgument;
    }
    const source_path = args[0];

    var custom_name: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--name") and i + 1 < args.len) {
            custom_name = args[i + 1];
            i += 1;
        }
    }

    const abs_path = try std.fs.cwd().realpathAlloc(allocator, source_path);
    defer allocator.free(abs_path);

    if (linker.isSymlink(abs_path)) {
        try stdout.print("Error: {s} is already a symlink\n", .{abs_path});
        return error.FileNotFound;
    }

    const name = custom_name orelse std.fs.path.basename(abs_path);

    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);

    const dest = try std.fs.path.join(allocator, &.{ repo_dir, name });
    defer allocator.free(dest);

    std.fs.cwd().rename(abs_path, dest) catch {
        try std.fs.cwd().copyFile(abs_path, std.fs.cwd(), dest, .{});
        try std.fs.cwd().deleteFile(abs_path);
    };

    try linker.createSymlink(dest, abs_path);

    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);
    var database = try db.Db.open(db_path_z);
    defer database.close();

    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);
    const abs_path_z = try allocator.dupeZ(u8, abs_path);
    defer allocator.free(abs_path_z);
    try database.addEntry(name_z, abs_path_z, "file");

    // Read auth from DB
    const repo_url = try database.getConfig(allocator, "repo_url");
    defer if (repo_url) |u| allocator.free(u);
    const token = try database.getConfig(allocator, "token");
    defer if (token) |t| allocator.free(t);

    // Git commit + push with auth
    const add_out = try git.addAll(allocator, repo_dir);
    allocator.free(add_out);
    const msg = try std.fmt.allocPrint(allocator, "add: {s}", .{name});
    defer allocator.free(msg);
    const commit_out = git.commit(allocator, repo_dir, msg) catch null;
    if (commit_out) |o| allocator.free(o);
    if (repo_url) |u| {
        git.pushWithAuth(allocator, repo_dir, u, token) catch |err| {
            try stdout.print("Warning: push failed ({}) — changes committed locally\n", .{err});
        };
    }

    try stdout.print("✓ Added {s} → {s}\n", .{ abs_path, dest });
}
