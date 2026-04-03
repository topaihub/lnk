const std = @import("std");
const git = @import("../core/git.zig");
const paths = @import("../platform/paths.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    const repo_dir = try paths.getRepoDir(allocator);
    defer allocator.free(repo_dir);

    try stdout.print("Pulling...\n", .{});
    const pull_out = git.pull(allocator, repo_dir) catch null;
    if (pull_out) |o| allocator.free(o);

    try stdout.print("Pushing...\n", .{});
    const add_out = try git.addAll(allocator, repo_dir);
    allocator.free(add_out);
    const commit_out = git.commit(allocator, repo_dir, "sync") catch null;
    if (commit_out) |o| allocator.free(o);
    const push_out = git.push(allocator, repo_dir) catch null;
    if (push_out) |o| allocator.free(o);

    try stdout.print("✓ Sync complete.\n", .{});
}
