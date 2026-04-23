const std = @import("std");
const App = @import("../app.zig").App;
const types = @import("../core/types.zig");

pub fn run(app: *App) !void {
    const repo_url = try app.store.getConfig(app.allocator, "repo_url");
    defer if (repo_url) |u| app.allocator.free(u);
    const token = try app.store.getConfig(app.allocator, "token");
    defer if (token) |t| app.allocator.free(t);

    std.debug.print("Pulling latest changes...\n", .{});
    if (repo_url) |u| {
        app.vcs.pullWithAuth(app.allocator, app.repo_dir, u, token) catch |err| {
            std.debug.print("Warning: pull failed ({})\n", .{err});
        };
    }

    const entries = try app.store.getAllEntries(app.allocator);
    defer types.freeEntries(app.allocator, entries);

    var restored: usize = 0;
    for (entries) |e| {
        const repo_file = try std.fs.path.join(app.allocator, &.{ app.repo_dir, e.name });
        defer app.allocator.free(repo_file);

        if (app.fs.isSymlink(e.original_path)) {
            const target = app.fs.readLink(app.allocator, e.original_path) catch continue;
            defer app.allocator.free(target);
            if (std.mem.eql(u8, target, repo_file)) continue;
            app.fs.removeSymlink(e.original_path) catch {};
        }

        app.fs.deleteFile(e.original_path) catch {};

        app.fs.createSymlink(repo_file, e.original_path) catch |err| {
            std.debug.print("  ✗ {s}: {}\n", .{ e.name, err });
            continue;
        };

        app.store.updateStatus(e.name, "linked") catch {};

        std.debug.print("  ✓ {s} → {s}\n", .{ e.name, e.original_path });
        restored += 1;
    }

    std.debug.print("\nRestored {d}/{d} entries.\n", .{ restored, entries.len });
}
