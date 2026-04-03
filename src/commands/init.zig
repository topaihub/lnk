const std = @import("std");
const db = @import("../core/db.zig");
const git = @import("../core/git.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        const stderr = std.fs.File.stderr().deprecatedWriter();
        try stderr.print("Usage: lnk init <repo-url> [--token <token>]\n", .{});
        return error.MissingArgument;
    }
    const repo_url = args[0];

    // Parse optional --token
    var token: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--token") and i + 1 < args.len) {
            token = args[i + 1];
            i += 1;
        }
    }
    // Also check env var
    const env_token = std.process.getEnvVarOwned(allocator, "LNK_TOKEN") catch null;
    defer if (env_token) |t| allocator.free(t);
    if (token == null and env_token != null) token = env_token.?;

    const lnk_home = try paths.getLnkHome(allocator);
    defer allocator.free(lnk_home);
    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);

    // Create ~/.lnk/
    try std.fs.cwd().makePath(lnk_home);

    // Build auth URL if token provided
    var clone_url_buf: [2048]u8 = undefined;
    var clone_url: []const u8 = repo_url;
    if (token) |t| {
        if (std.mem.startsWith(u8, repo_url, "https://")) {
            const rest = repo_url["https://".len..];
            const result = std.fmt.bufPrint(&clone_url_buf, "https://{s}@{s}", .{ t, rest }) catch return error.UrlTooLong;
            clone_url = result;
        }
    }

    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("Cloning {s} ...\n", .{repo_url});
    const clone_out = try git.clone(allocator, clone_url, repo_dir);
    allocator.free(clone_out);

    // Init DB
    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);
    var database = try db.Db.open(db_path_z);
    defer database.close();

    const repo_url_z = try allocator.dupeZ(u8, repo_url);
    defer allocator.free(repo_url_z);
    try database.setConfig("repo_url", repo_url_z);

    if (token) |t| {
        const token_z = try allocator.dupeZ(u8, t);
        defer allocator.free(token_z);
        try database.setConfig("token", token_z);
    }

    try stdout.print("✓ Initialized lnk at {s}\n", .{lnk_home});
}
