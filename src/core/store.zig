const std = @import("std");
const types = @import("types.zig");

pub const Store = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        add_entry: *const fn (ptr: *anyopaque, name: []const u8, original_path: []const u8, entry_type: []const u8) anyerror!void,
        delete_entry: *const fn (ptr: *anyopaque, name: []const u8) anyerror!void,
        get_all_entries: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]types.Entry,
        get_config: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8,
        set_config: *const fn (ptr: *anyopaque, key: []const u8, value: []const u8) anyerror!void,
        update_status: *const fn (ptr: *anyopaque, name: []const u8, status: []const u8) anyerror!void,
        close: *const fn (ptr: *anyopaque) void,
    };

    pub fn addEntry(self: Store, name: []const u8, original_path: []const u8, entry_type: []const u8) !void {
        return self.vtable.add_entry(self.ptr, name, original_path, entry_type);
    }

    pub fn deleteEntry(self: Store, name: []const u8) !void {
        return self.vtable.delete_entry(self.ptr, name);
    }

    pub fn getAllEntries(self: Store, allocator: std.mem.Allocator) ![]types.Entry {
        return self.vtable.get_all_entries(self.ptr, allocator);
    }

    pub fn getConfig(self: Store, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        return self.vtable.get_config(self.ptr, allocator, key);
    }

    pub fn setConfig(self: Store, key: []const u8, value: []const u8) !void {
        return self.vtable.set_config(self.ptr, key, value);
    }

    pub fn updateStatus(self: Store, name: []const u8, status: []const u8) !void {
        return self.vtable.update_status(self.ptr, name, status);
    }

    pub fn close(self: Store) void {
        return self.vtable.close(self.ptr);
    }
};
