const std = @import("std");
const db = @import("../core/db.zig");
const linker = @import("../core/linker.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

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
        try stdout.print("No tracked files.\n", .{});
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
        try stdout.print("{s} {s:<20} {s}\n", .{ icon, e.name, e.original_path });
    }
}
