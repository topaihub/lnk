const std = @import("std");
const App = @import("../app.zig").App;

pub fn run(app: *App) !void {
    const repo_url = try app.store.getConfig(app.allocator, "repo_url");
    defer if (repo_url) |u| app.allocator.free(u);
    const token = try app.store.getConfig(app.allocator, "token");
    defer if (token) |t| app.allocator.free(t);

    if (repo_url) |u| {
        std.debug.print("Pulling...\n", .{});
        app.vcs.pullWithAuth(app.allocator, app.repo_dir, u, token) catch |err| {
            std.debug.print("Pull failed: {}\n", .{err});
        };

        std.debug.print("Pushing...\n", .{});
        try app.vcs.addAll(app.allocator, app.repo_dir);
        app.vcs.commit(app.allocator, app.repo_dir, "sync") catch {};
        app.vcs.pushWithAuth(app.allocator, app.repo_dir, u, token) catch |err| {
            std.debug.print("Push failed: {}\n", .{err});
        };
    }

    std.debug.print("✓ Sync complete.\n", .{});
}
