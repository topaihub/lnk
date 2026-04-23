const std = @import("std");

pub const Entry = struct {
    name: []const u8,
    original_path: []const u8,
    entry_type: []const u8,
    status: []const u8,
};

pub const RepoAuth = struct {
    repo_url: []const u8,
    token: ?[]const u8,
};

pub fn freeEntries(allocator: std.mem.Allocator, entries: []Entry) void {
    for (entries) |e| {
        allocator.free(e.name);
        allocator.free(e.original_path);
        allocator.free(e.entry_type);
        allocator.free(e.status);
    }
    allocator.free(entries);
}
