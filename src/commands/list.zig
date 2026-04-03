const std = @import("std");
const db = @import("../core/db.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

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
        try stdout.print("No tracked files. Use 'lnk add <path>' to start.\n", .{});
        return;
    }

    try stdout.print("{s:<20} {s:<40} {s:<10}\n", .{ "NAME", "ORIGINAL PATH", "STATUS" });
    for (entries) |e| {
        try stdout.print("{s:<20} {s:<40} {s:<10}\n", .{ e.name, e.original_path, e.status });
    }
}
