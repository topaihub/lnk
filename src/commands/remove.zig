const std = @import("std");
const App = @import("../app.zig").App;
const types = @import("../core/types.zig");

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: lnk remove <name>\n", .{});
        return error.MissingArgument;
    }
    const name = args[0];

    const entries = try app.store.getAllEntries(app.allocator);
    defer types.freeEntries(app.allocator, entries);

    var original_path: ?[]const u8 = null;
    for (entries) |e| {
        if (std.mem.eql(u8, e.name, name)) {
            original_path = e.original_path;
            break;
        }
    }
    if (original_path == null) {
        std.debug.print("Error: '{s}' not found in tracked files\n", .{name});
        return error.FileNotFound;
    }

    const repo_file = try std.fs.path.join(app.allocator, &.{ app.repo_dir, name });
    defer app.allocator.free(repo_file);

    if (app.fs.isSymlink(original_path.?)) {
        app.fs.removeSymlink(original_path.?) catch {};
    }
    app.fs.copyFile(repo_file, original_path.?) catch {};
    app.fs.deleteFile(repo_file) catch {};

    try app.store.deleteEntry(name);

    // Git commit + push
    const repo_url = try app.store.getConfig(app.allocator, "repo_url");
    defer if (repo_url) |u| app.allocator.free(u);
    const token = try app.store.getConfig(app.allocator, "token");
    defer if (token) |t| app.allocator.free(t);

    try app.vcs.addAll(app.allocator, app.repo_dir);
    const msg = try std.fmt.allocPrint(app.allocator, "remove: {s}", .{name});
    defer app.allocator.free(msg);
    app.vcs.commit(app.allocator, app.repo_dir, msg) catch {};
    if (repo_url) |u| {
        app.vcs.pushWithAuth(app.allocator, app.repo_dir, u, token) catch {};
    }

    std.debug.print("✓ Removed {s}, restored to {s}\n", .{ name, original_path.? });
}
