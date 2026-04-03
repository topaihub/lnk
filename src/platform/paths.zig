const std = @import("std");
const builtin = @import("builtin");

pub fn getHomeDir(allocator: std.mem.Allocator) ![]u8 {
    if (builtin.os.tag == .windows) {
        return std.process.getEnvVarOwned(allocator, "USERPROFILE");
    }
    return std.process.getEnvVarOwned(allocator, "HOME");
}

pub fn getLnkHome(allocator: std.mem.Allocator) ![]u8 {
    const home = try getHomeDir(allocator);
    defer allocator.free(home);
    return std.fs.path.join(allocator, &.{ home, ".lnk" });
}

pub fn getRepoDir(allocator: std.mem.Allocator) ![]u8 {
    const lnk_home = try getLnkHome(allocator);
    defer allocator.free(lnk_home);
    return std.fs.path.join(allocator, &.{ lnk_home, "repo" });
}

pub fn getDbPath(allocator: std.mem.Allocator) ![]u8 {
    const lnk_home = try getLnkHome(allocator);
    defer allocator.free(lnk_home);
    return std.fs.path.join(allocator, &.{ lnk_home, "lnk.db" });
}
