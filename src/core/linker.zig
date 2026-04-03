const std = @import("std");

pub fn createSymlink(target: []const u8, link_path: []const u8) !void {
    // Ensure parent directory exists
    if (std.fs.path.dirname(link_path)) |dir| {
        std.fs.cwd().makePath(dir) catch {};
    }
    try std.fs.cwd().symLink(target, link_path, .{});
}

pub fn removeSymlink(path: []const u8) !void {
    try std.fs.cwd().deleteFile(path);
}

pub fn isSymlink(path: []const u8) bool {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = std.fs.cwd().readLink(path, &buf) catch return false;
    return true;
}

pub fn readLink(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const target = try std.fs.cwd().readLink(path, &buf);
    return try allocator.dupe(u8, target);
}
