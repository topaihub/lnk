const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    try stdout.print("Pulling latest changes...\n", .{});
    const pull_out = git.pull(allocator, repo_dir) catch null;
    if (pull_out) |o| allocator.free(o);

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
            linker.removeSymlink(e.original_path) catch {};
        }

        // Remove existing file at original path if present
        std.fs.cwd().deleteFile(e.original_path) catch {};

        linker.createSymlink(repo_file, e.original_path) catch |err| {
            try stdout.print("  ✗ {s}: {}\n", .{ e.name, err });
            continue;
        };

        const name_z = try allocator.dupeZ(u8, e.name);
        defer allocator.free(name_z);
        database.updateStatus(name_z, "linked") catch {};

        try stdout.print("  ✓ {s} → {s}\n", .{ e.name, e.original_path });
        restored += 1;
    }

    try stdout.print("\nRestored {d}/{d} entries.\n", .{ restored, entries.len });
}
