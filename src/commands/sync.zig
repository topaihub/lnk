const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    var database = try db.Db.open(db_path_z);
    defer database.close();

    const repo_url = try database.getConfig(allocator, "repo_url");
    defer if (repo_url) |u| allocator.free(u);
    const token = try database.getConfig(allocator, "token");
    defer if (token) |t| allocator.free(t);

    if (repo_url) |u| {
        try stdout.print("Pulling...\n", .{});
        git.pullWithAuth(allocator, repo_dir, u, token) catch |err| {
            try stdout.print("Pull failed: {}\n", .{err});
        };

        try stdout.print("Pushing...\n", .{});
        const add_out = try git.addAll(allocator, repo_dir);
        allocator.free(add_out);
        const commit_out = git.commit(allocator, repo_dir, "sync") catch null;
        if (commit_out) |o| allocator.free(o);
        git.pushWithAuth(allocator, repo_dir, u, token) catch |err| {
            try stdout.print("Push failed: {}\n", .{err});
        };
    }

    try stdout.print("✓ Sync complete.\n", .{});
}
