const std = @import("std");

pub const Vcs = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        clone: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, url: []const u8, dest: []const u8) anyerror!void,
        add_all: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8) anyerror!void,
        commit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, message: []const u8) anyerror!void,
        push_with_auth: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) anyerror!void,
        pull_with_auth: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) anyerror!void,
        set_remote_url: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, repo_dir: []const u8, url: []const u8) anyerror!void,
    };

    pub fn clone(self: Vcs, allocator: std.mem.Allocator, url: []const u8, dest: []const u8) !void {
        return self.vtable.clone(self.ptr, allocator, url, dest);
    }

    pub fn addAll(self: Vcs, allocator: std.mem.Allocator, repo_dir: []const u8) !void {
        return self.vtable.add_all(self.ptr, allocator, repo_dir);
    }

    pub fn commit(self: Vcs, allocator: std.mem.Allocator, repo_dir: []const u8, message: []const u8) !void {
        return self.vtable.commit(self.ptr, allocator, repo_dir, message);
    }

    pub fn pushWithAuth(self: Vcs, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) !void {
        return self.vtable.push_with_auth(self.ptr, allocator, repo_dir, repo_url, token);
    }

    pub fn pullWithAuth(self: Vcs, allocator: std.mem.Allocator, repo_dir: []const u8, repo_url: []const u8, token: ?[]const u8) !void {
        return self.vtable.pull_with_auth(self.ptr, allocator, repo_dir, repo_url, token);
    }

    pub fn setRemoteUrl(self: Vcs, allocator: std.mem.Allocator, repo_dir: []const u8, url: []const u8) !void {
        return self.vtable.set_remote_url(self.ptr, allocator, repo_dir, url);
    }
};
