const std = @import("std");
const App = @import("../app.zig").App;

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: lnk init <repo-url> [--token <token>]\n", .{});
        return error.MissingArgument;
    }
    const repo_url = args[0];

    var token: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--token") and i + 1 < args.len) {
            token = args[i + 1];
            i += 1;
        }
    }
    const env_token: ?[]const u8 = if (std.c.getenv("LNK_TOKEN")) |t| std.mem.sliceTo(t, 0) else null;
    if (token == null and env_token != null) token = env_token.?;

    // Create ~/.lnk/
    try app.fs.makePath(app.lnk_home);

    // Build auth URL for clone
    const clone_url = try authUrl(app.allocator, repo_url, token);
    defer app.allocator.free(clone_url);

    std.debug.print("Cloning {s} ...\n", .{repo_url});
    try app.vcs.clone(app.allocator, clone_url, app.repo_dir);

    // Reset remote URL to clean (no token)
    try app.vcs.setRemoteUrl(app.allocator, app.repo_dir, repo_url);

    try app.store.setConfig("repo_url", repo_url);
    if (token) |t| {
        try app.store.setConfig("token", t);
    }

    // Set DB file permissions to 600 (POSIX only)
    if (@import("builtin").os.tag != .windows) {
        const db_path = try std.fs.path.join(app.allocator, &.{ app.lnk_home, "lnk.db" });
        defer app.allocator.free(db_path);
        const db_path_z = try app.allocator.dupeZ(u8, db_path);
        defer app.allocator.free(db_path_z);
        _ = std.c.chmod(db_path_z, 0o600);
    }

    std.debug.print("✓ Initialized lnk at {s}\n", .{app.lnk_home});
}

fn authUrl(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8) ![]u8 {
    const t = token orelse return try allocator.dupe(u8, url);
    if (!std.mem.startsWith(u8, url, "https://")) return try allocator.dupe(u8, url);
    const rest = url["https://".len..];
    return try std.fmt.allocPrint(allocator, "https://{s}@{s}", .{ t, rest });
}
