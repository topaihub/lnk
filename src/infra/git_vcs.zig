const std = @import("std");
const Vcs = @import("../core/vcs.zig").Vcs;

pub const GitVcs = struct {
    io: std.Io,

    fn runGit(self: *GitVcs, allocator: std.mem.Allocator, cwd: ?[]const u8, argv: []const []const u8) !void {
        const result = try std.process.run(allocator, self.io, .{
            .argv = argv,
            .cwd = if (cwd) |d| .{ .path = d } else .inherit,
        });
        allocator.free(result.stderr);
        defer allocator.free(result.stdout);
        if (result.term != .exited or result.term.exited != 0) return error.GitFailed;
    }

    fn authUrl(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8) ![]u8 {
        const t = token orelse return try allocator.dupe(u8, url);
        if (!std.mem.startsWith(u8, url, "https://")) return try allocator.dupe(u8, url);
        const rest = url["https://".len..];
        return try std.fmt.allocPrint(allocator, "https://{s}@{s}", .{ t, rest });
    }

    fn cloneImpl(self: *GitVcs, allocator: std.mem.Allocator, url: []const u8, dest: []const u8) !void {
        try self.runGit(allocator, null, &.{ "git", "clone", url, dest });
    }

    fn addAllImpl(self: *GitVcs, allocator: std.mem.Allocator, repo_dir: []const u8) !void {
        try self.runGit(allocator, repo_dir, &.{ "git", "add", "-A" });
    }

    fn commitImpl(self: *GitVcs, allocator: std.mem.Allocator, repo_dir: []const u8, message: []const u8) !void {
        try self.runGit(allocator, repo_dir, &.{ "git", "commit", "-m", message });
    }

    fn setRemoteUrlImpl(self: *GitVcs, allocator: std.mem.Allocator, repo_dir: []const u8, url: []const u8) !void {
        try self.runGit(allocator, repo_dir, &.{ "git", "remote", "set-url", "origin", url });
    }

    fn pushWithAuthImpl(self: *GitVcs, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) !void {
        const auth = try authUrl(allocator, repo_url, token);
        defer allocator.free(auth);
        self.runGit(allocator, repo_dir, &.{ "git", "remote", "set-url", "origin", auth }) catch {};
        defer self.runGit(allocator, repo_dir, &.{ "git", "remote", "set-url", "origin", repo_url }) catch {};
        try self.runGit(allocator, repo_dir, &.{ "git", "push" });
    }

    fn pullWithAuthImpl(self: *GitVcs, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) !void {
        const auth = try authUrl(allocator, repo_url, token);
        defer allocator.free(auth);
        self.runGit(allocator, repo_dir, &.{ "git", "remote", "set-url", "origin", auth }) catch {};
        defer self.runGit(allocator, repo_dir, &.{ "git", "remote", "set-url", "origin", repo_url }) catch {};
        try self.runGit(allocator, repo_dir, &.{ "git", "pull" });
    }

    // VTable wrappers
    fn vtClone(ptr: *anyopaque, allocator: std.mem.Allocator, url: []const u8, dest: []const u8) anyerror!void {
        const self: *GitVcs = @ptrCast(@alignCast(ptr));
        return self.cloneImpl(allocator, url, dest);
    }
    fn vtAddAll(ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8) anyerror!void {
        const self: *GitVcs = @ptrCast(@alignCast(ptr));
        return self.addAllImpl(allocator, repo_dir);
    }
    fn vtCommit(ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, message: []const u8) anyerror!void {
        const self: *GitVcs = @ptrCast(@alignCast(ptr));
        return self.commitImpl(allocator, repo_dir, message);
    }
    fn vtPushWithAuth(ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) anyerror!void {
        const self: *GitVcs = @ptrCast(@alignCast(ptr));
        return self.pushWithAuthImpl(allocator, repo_dir, repo_url, token);
    }
    fn vtPullWithAuth(ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) anyerror!void {
        const self: *GitVcs = @ptrCast(@alignCast(ptr));
        return self.pullWithAuthImpl(allocator, repo_dir, repo_url, token);
    }
    fn vtSetRemoteUrl(ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, url: []const u8) anyerror!void {
        const self: *GitVcs = @ptrCast(@alignCast(ptr));
        return self.setRemoteUrlImpl(allocator, repo_dir, url);
    }

    const vtable = Vcs.VTable{
        .clone = vtClone,
        .add_all = vtAddAll,
        .commit = vtCommit,
        .push_with_auth = vtPushWithAuth,
        .pull_with_auth = vtPullWithAuth,
        .set_remote_url = vtSetRemoteUrl,
    };

    pub fn vcs(self: *GitVcs) Vcs {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }
};
