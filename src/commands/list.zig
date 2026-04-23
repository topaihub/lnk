const std = @import("std");
const App = @import("../app.zig").App;
const types = @import("../core/types.zig");

pub fn run(app: *App) !void {
    const entries = try app.store.getAllEntries(app.allocator);
    defer types.freeEntries(app.allocator, entries);

    if (entries.len == 0) {
        std.debug.print("No tracked files. Use 'lnk add <path>' to start.\n", .{});
        return;
    }

    std.debug.print("{s:<20} {s:<40} {s:<10}\n", .{ "NAME", "ORIGINAL PATH", "STATUS" });
    for (entries) |e| {
        std.debug.print("{s:<20} {s:<40} {s:<10}\n", .{ e.name, e.original_path, e.status });
    }
}
