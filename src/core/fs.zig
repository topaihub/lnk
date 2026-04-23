const std = @import("std");

pub const Fs = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        create_symlink: *const fn (ptr: *anyopaque, target: []const u8, link_path: []const u8) anyerror!void,
        remove_symlink: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        is_symlink: *const fn (ptr: *anyopaque, path: []const u8) bool,
        read_link: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) anyerror![]u8,
        copy_file: *const fn (ptr: *anyopaque, src: []const u8, dest: []const u8) anyerror!void,
        delete_file: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        rename: *const fn (ptr: *anyopaque, old: []const u8, new: []const u8) anyerror!void,
        make_path: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        realpath_alloc: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) anyerror![]u8,
        access: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
    };

    pub fn createSymlink(self: Fs, target: []const u8, link_path: []const u8) !void {
        return self.vtable.create_symlink(self.ptr, target, link_path);
    }

    pub fn removeSymlink(self: Fs, path: []const u8) !void {
        return self.vtable.remove_symlink(self.ptr, path);
    }

    pub fn isSymlink(self: Fs, path: []const u8) bool {
        return self.vtable.is_symlink(self.ptr, path);
    }

    pub fn readLink(self: Fs, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        return self.vtable.read_link(self.ptr, allocator, path);
    }

    pub fn copyFile(self: Fs, src: []const u8, dest: []const u8) !void {
        return self.vtable.copy_file(self.ptr, src, dest);
    }

    pub fn deleteFile(self: Fs, path: []const u8) !void {
        return self.vtable.delete_file(self.ptr, path);
    }

    pub fn rename(self: Fs, old: []const u8, new: []const u8) !void {
        return self.vtable.rename(self.ptr, old, new);
    }

    pub fn makePath(self: Fs, path: []const u8) !void {
        return self.vtable.make_path(self.ptr, path);
    }

    pub fn realpathAlloc(self: Fs, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        return self.vtable.realpath_alloc(self.ptr, allocator, path);
    }

    pub fn access(self: Fs, path: []const u8) !void {
        return self.vtable.access(self.ptr, path);
    }
};
