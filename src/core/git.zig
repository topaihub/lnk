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

pub fn clone(allocator: std.mem.Allocator, url: []const u8, dest: []const u8) ![]u8 {
    return runGit(allocator, null, &.{ "git", "clone", url, dest });
}

pub fn addAll(allocator: std.mem.Allocator, repo_dir: []const u8) ![]u8 {
    return runGit(allocator, repo_dir, &.{ "git", "add", "-A" });
}

pub fn commit(allocator: std.mem.Allocator, repo_dir: []const u8, message: []const u8) ![]u8 {
    return runGit(allocator, repo_dir, &.{ "git", "commit", "-m", message });
}

pub fn push(allocator: std.mem.Allocator, repo_dir: []const u8) ![]u8 {
    return runGit(allocator, repo_dir, &.{ "git", "push" });
}

pub fn pull(allocator: std.mem.Allocator, repo_dir: []const u8) ![]u8 {
    return runGit(allocator, repo_dir, &.{ "git", "pull" });
}
