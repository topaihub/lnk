const std = @import("std");
const App = @import("../app.zig").App;

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: lnk add <path> [--name <name>]\n", .{});
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

    const abs_path = try app.fs.realpathAlloc(app.allocator, source_path);
    defer app.allocator.free(abs_path);

    if (app.fs.isSymlink(abs_path)) {
        std.debug.print("Error: {s} is already a symlink\n", .{abs_path});
        return error.FileNotFound;
    }

    const name = custom_name orelse std.fs.path.basename(abs_path);

    const dest = try std.fs.path.join(app.allocator, &.{ app.repo_dir, name });
    defer app.allocator.free(dest);

    // Move file to repo
    app.fs.rename(abs_path, dest) catch {
        try app.fs.copyFile(abs_path, dest);
        try app.fs.deleteFile(abs_path);
    };

    try app.fs.createSymlink(dest, abs_path);
    try app.store.addEntry(name, abs_path, "file");

    // Git commit + push
    const repo_url = try app.store.getConfig(app.allocator, "repo_url");
    defer if (repo_url) |u| app.allocator.free(u);
    const token = try app.store.getConfig(app.allocator, "token");
    defer if (token) |t| app.allocator.free(t);

    try app.vcs.addAll(app.allocator, app.repo_dir);
    const msg = try std.fmt.allocPrint(app.allocator, "add: {s}", .{name});
    defer app.allocator.free(msg);
    app.vcs.commit(app.allocator, app.repo_dir, msg) catch {};
    if (repo_url) |u| {
        app.vcs.pushWithAuth(app.allocator, app.repo_dir, u, token) catch |err| {
            std.debug.print("Warning: push failed ({}) — changes committed locally\n", .{err});
        };
    }

    std.debug.print("✓ Added {s} → {s}\n", .{ abs_path, dest });
}
