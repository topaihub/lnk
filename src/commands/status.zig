const std = @import("std");
const App = @import("../app.zig").App;
const types = @import("../core/types.zig");

pub fn run(app: *App) !void {
    const entries = try app.store.getAllEntries(app.allocator);
    defer types.freeEntries(app.allocator, entries);

    if (entries.len == 0) {
        std.debug.print("No tracked files.\n", .{});
        return;
    }

    for (entries) |e| {
        const repo_path = try std.fs.path.join(app.allocator, &.{ app.repo_dir, e.name });
        defer app.allocator.free(repo_path);

        const in_repo = blk: {
            app.fs.access(repo_path) catch break :blk false;
            break :blk true;
        };
        const is_linked = app.fs.isSymlink(e.original_path);

        const icon: []const u8 = if (in_repo and is_linked) "✓" else if (in_repo) "⚠" else "✗";
        std.debug.print("{s} {s:<20} {s}\n", .{ icon, e.name, e.original_path });
    }
}
