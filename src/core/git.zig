const std = @import("std");

pub const GitError = error{
    GitFailed,
};

fn runGit(allocator: std.mem.Allocator, cwd: ?[]const u8, argv: []const []const u8) ![]u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = cwd,
    });
    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        return GitError.GitFailed;
    }
    return result.stdout;
}

/// Build authenticated URL: https://token@github.com/user/repo.git
pub fn authUrl(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8) ![]u8 {
    const t = token orelse return try allocator.dupe(u8, url);
    if (!std.mem.startsWith(u8, url, "https://")) return try allocator.dupe(u8, url);
    const rest = url["https://".len..];
    return try std.fmt.allocPrint(allocator, "https://{s}@{s}", .{ t, rest });
}

pub fn clone(allocator: std.mem.Allocator, url: []const u8, dest: []const u8) ![]u8 {
    return runGit(allocator, null, &.{ "git", "clone", url, dest });
}

/// Set remote origin URL (used to inject/remove token temporarily)
pub fn setRemoteUrl(allocator: std.mem.Allocator, repo_dir: []const u8, url: []const u8) !void {
    const out = try runGit(allocator, repo_dir, &.{ "git", "remote", "set-url", "origin", url });
    allocator.free(out);
}

pub fn addAll(allocator: std.mem.Allocator, repo_dir: []const u8) ![]u8 {
    return runGit(allocator, repo_dir, &.{ "git", "add", "-A" });
}

pub fn commit(allocator: std.mem.Allocator, repo_dir: []const u8, message: []const u8) ![]u8 {
    return runGit(allocator, repo_dir, &.{ "git", "commit", "-m", message });
}

/// Push with token: temporarily set auth URL, push, restore clean URL
pub fn pushWithAuth(allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) !void {
    const auth = try authUrl(allocator, repo_url, token);
    defer allocator.free(auth);
    try setRemoteUrl(allocator, repo_dir, auth);
    defer setRemoteUrl(allocator, repo_dir, repo_url) catch {};
    const out = try runGit(allocator, repo_dir, &.{ "git", "push" });
    allocator.free(out);
}

/// Pull with token: temporarily set auth URL, pull, restore clean URL
pub fn pullWithAuth(allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) !void {
    const auth = try authUrl(allocator, repo_url, token);
    defer allocator.free(auth);
    try setRemoteUrl(allocator, repo_dir, auth);
    defer setRemoteUrl(allocator, repo_dir, repo_url) catch {};
    const out = try runGit(allocator, repo_dir, &.{ "git", "pull" });
    allocator.free(out);
}
