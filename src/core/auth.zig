const std = @import("std");
const db = @import("db.zig");
const paths = @import("../platform/paths.zig");

pub const RepoAuth = struct {
    repo_url: []u8,
    token: ?[]u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *RepoAuth) void {
        self.allocator.free(self.repo_url);
        if (self.token) |t| self.allocator.free(t);
    }
};

/// Open DB and read repo_url + token
pub fn loadAuth(allocator: std.mem.Allocator) !struct { database: db.Db, auth: RepoAuth, db_path_z: [:0]u8 } {
    const db_path = try paths.getDbPath(allocator);
    defer allocator.free(db_path);
    const db_path_z = try allocator.dupeZ(u8, db_path);

    var database = try db.Db.open(db_path_z);

    const repo_url = try database.getConfig(allocator, "repo_url") orelse return error.NotInitialized;
    const token = try database.getConfig(allocator, "token");

    return .{
        .database = database,
        .auth = .{
            .repo_url = repo_url,
            .token = token,
            .allocator = allocator,
        },
        .db_path_z = db_path_z,
    };
}
