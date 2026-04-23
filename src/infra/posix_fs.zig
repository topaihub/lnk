const std = @import("std");
const Fs = @import("../core/fs.zig").Fs;
const Dir = std.Io.Dir;

pub const PosixFs = struct {
    io: std.Io,

    fn createSymlinkImpl(self: *PosixFs, target: []const u8, link_path: []const u8) !void {
        if (std.fs.path.dirname(link_path)) |dir| {
            Dir.cwd().createDirPath(self.io, dir) catch {};
        }
        Dir.cwd().symLink(self.io, target, link_path, .{}) catch |err| return err;
    }

    fn removeSymlinkImpl(self: *PosixFs, path: []const u8) !void {
        try Dir.cwd().deleteFile(self.io, path);
    }

    fn isSymlinkImpl(self: *PosixFs, path: []const u8) bool {
        var buf: [Dir.max_path_bytes]u8 = undefined;
        _ = Dir.cwd().readLink(self.io, path, &buf) catch return false;
        return true;
    }

    fn readLinkImpl(self: *PosixFs, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        var buf: [Dir.max_path_bytes]u8 = undefined;
        const len = try Dir.cwd().readLink(self.io, path, &buf);
        return try allocator.dupe(u8, buf[0..len]);
    }

    fn copyFileImpl(self: *PosixFs, src: []const u8, dest: []const u8) !void {
        Dir.copyFile(Dir.cwd(), src, Dir.cwd(), dest, self.io, .{}) catch |err| return err;
    }

    fn deleteFileImpl(self: *PosixFs, path: []const u8) !void {
        try Dir.cwd().deleteFile(self.io, path);
    }

    fn renameImpl(self: *PosixFs, old: []const u8, new: []const u8) !void {
        Dir.rename(Dir.cwd(), old, Dir.cwd(), new, self.io) catch |err| return err;
    }

    fn makePathImpl(self: *PosixFs, path: []const u8) !void {
        try Dir.cwd().createDirPath(self.io, path);
    }

    fn realpathAllocImpl(self: *PosixFs, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        return std.Io.Dir.cwd().realPathFileAlloc(self.io, path, allocator);
    }

    fn accessImpl(self: *PosixFs, path: []const u8) !void {
        try Dir.cwd().access(self.io, path, .{});
    }

    // VTable wrappers
    fn vtCreateSymlink(ptr: *anyopaque, target: []const u8, link_path: []const u8) anyerror!void {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.createSymlinkImpl(target, link_path);
    }
    fn vtRemoveSymlink(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.removeSymlinkImpl(path);
    }
    fn vtIsSymlink(ptr: *anyopaque, path: []const u8) bool {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.isSymlinkImpl(path);
    }
    fn vtReadLink(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) anyerror![]u8 {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.readLinkImpl(allocator, path);
    }
    fn vtCopyFile(ptr: *anyopaque, src: []const u8, dest: []const u8) anyerror!void {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.copyFileImpl(src, dest);
    }
    fn vtDeleteFile(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.deleteFileImpl(path);
    }
    fn vtRename(ptr: *anyopaque, old: []const u8, new: []const u8) anyerror!void {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.renameImpl(old, new);
    }
    fn vtMakePath(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.makePathImpl(path);
    }
    fn vtRealpathAlloc(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) anyerror![]u8 {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.realpathAllocImpl(allocator, path);
    }
    fn vtAccess(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *PosixFs = @ptrCast(@alignCast(ptr));
        return self.accessImpl(path);
    }

    const vtable = Fs.VTable{
        .create_symlink = vtCreateSymlink,
        .remove_symlink = vtRemoveSymlink,
        .is_symlink = vtIsSymlink,
        .read_link = vtReadLink,
        .copy_file = vtCopyFile,
        .delete_file = vtDeleteFile,
        .rename = vtRename,
        .make_path = vtMakePath,
        .realpath_alloc = vtRealpathAlloc,
        .access = vtAccess,
    };

    pub fn fs(self: *PosixFs) Fs {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }
};
