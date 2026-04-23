const std = @import("std");
const types = @import("../core/types.zig");
const Store = @import("../core/store.zig").Store;
const c = @cImport({
    @cInclude("sqlite3.h");
});

// SQLITE_TRANSIENT = (sqlite3_destructor_type)(-1)
// Manual definition because @cImport can't translate this on all platforms in Zig 0.16
const SQLITE_TRANSIENT: c.sqlite3_destructor_type = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));

pub const SqliteStore = struct {
    handle: ?*c.sqlite3 = null,

    pub fn open(path: [*:0]const u8) !SqliteStore {
        var self = SqliteStore{};
        if (c.sqlite3_open(path, &self.handle) != c.SQLITE_OK) return error.SqliteOpenFailed;
        try self.exec(
            \\CREATE TABLE IF NOT EXISTS entries (
            \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  name TEXT UNIQUE NOT NULL,
            \\  original_path TEXT NOT NULL,
            \\  type TEXT NOT NULL DEFAULT 'file',
            \\  status TEXT NOT NULL DEFAULT 'linked',
            \\  created_at TEXT DEFAULT (datetime('now')),
            \\  updated_at TEXT DEFAULT (datetime('now'))
            \\);
            \\CREATE TABLE IF NOT EXISTS config (
            \\  key TEXT PRIMARY KEY,
            \\  value TEXT NOT NULL
            \\);
        );
        return self;
    }

    fn exec(self: *SqliteStore, sql: [*:0]const u8) !void {
        if (c.sqlite3_exec(self.handle, sql, null, null, null) != c.SQLITE_OK) return error.SqliteExecFailed;
    }

    fn bindText(stmt: ?*c.sqlite3_stmt, col: c_int, text: []const u8) void {
        _ = c.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), SQLITE_TRANSIENT);
    }

    fn dupeCol(allocator: std.mem.Allocator, stmt: ?*c.sqlite3_stmt, col: c_int) ![]const u8 {
        const raw: [*c]const u8 = c.sqlite3_column_text(stmt, col);
        const len: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        return try allocator.dupe(u8, raw[0..len]);
    }

    fn addEntryImpl(self: *SqliteStore, name: []const u8, original_path: []const u8, entry_type: []const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "INSERT INTO entries(name,original_path,type) VALUES(?,?,?)", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, name);
        bindText(stmt, 2, original_path);
        bindText(stmt, 3, entry_type);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    fn deleteEntryImpl(self: *SqliteStore, name: []const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "DELETE FROM entries WHERE name=?", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, name);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    fn getAllEntriesImpl(self: *SqliteStore, allocator: std.mem.Allocator) ![]types.Entry {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "SELECT name,original_path,type,status FROM entries", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        var list: std.ArrayListUnmanaged(types.Entry) = .empty;
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            try list.append(allocator, .{
                .name = try dupeCol(allocator, stmt, 0),
                .original_path = try dupeCol(allocator, stmt, 1),
                .entry_type = try dupeCol(allocator, stmt, 2),
                .status = try dupeCol(allocator, stmt, 3),
            });
        }
        return try list.toOwnedSlice(allocator);
    }

    fn getConfigImpl(self: *SqliteStore, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "SELECT value FROM config WHERE key=?", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, key);
        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) return null;
        return try dupeCol(allocator, stmt, 0);
    }

    fn setConfigImpl(self: *SqliteStore, key: []const u8, value: []const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "INSERT OR REPLACE INTO config(key,value) VALUES(?,?)", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, key);
        bindText(stmt, 2, value);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    fn updateStatusImpl(self: *SqliteStore, name: []const u8, status: []const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "UPDATE entries SET status=?,updated_at=datetime('now') WHERE name=?", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, status);
        bindText(stmt, 2, name);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    fn closeImpl(self: *SqliteStore) void {
        if (self.handle) |h| _ = c.sqlite3_close(h);
        self.handle = null;
    }

    // VTable wrappers
    fn vtAddEntry(ptr: *anyopaque, name: []const u8, original_path: []const u8, entry_type: []const u8) anyerror!void {
        const self: *SqliteStore = @ptrCast(@alignCast(ptr));
        return self.addEntryImpl(name, original_path, entry_type);
    }
    fn vtDeleteEntry(ptr: *anyopaque, name: []const u8) anyerror!void {
        const self: *SqliteStore = @ptrCast(@alignCast(ptr));
        return self.deleteEntryImpl(name);
    }
    fn vtGetAllEntries(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]types.Entry {
        const self: *SqliteStore = @ptrCast(@alignCast(ptr));
        return self.getAllEntriesImpl(allocator);
    }
    fn vtGetConfig(ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8 {
        const self: *SqliteStore = @ptrCast(@alignCast(ptr));
        return self.getConfigImpl(allocator, key);
    }
    fn vtSetConfig(ptr: *anyopaque, key: []const u8, value: []const u8) anyerror!void {
        const self: *SqliteStore = @ptrCast(@alignCast(ptr));
        return self.setConfigImpl(key, value);
    }
    fn vtUpdateStatus(ptr: *anyopaque, name: []const u8, status: []const u8) anyerror!void {
        const self: *SqliteStore = @ptrCast(@alignCast(ptr));
        return self.updateStatusImpl(name, status);
    }
    fn vtClose(ptr: *anyopaque) void {
        const self: *SqliteStore = @ptrCast(@alignCast(ptr));
        self.closeImpl();
    }

    const vtable = Store.VTable{
        .add_entry = vtAddEntry,
        .delete_entry = vtDeleteEntry,
        .get_all_entries = vtGetAllEntries,
        .get_config = vtGetConfig,
        .set_config = vtSetConfig,
        .update_status = vtUpdateStatus,
        .close = vtClose,
    };

    pub fn store(self: *SqliteStore) Store {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }
};
