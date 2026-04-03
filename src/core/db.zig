const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const Entry = struct {
    name: []const u8,
    original_path: []const u8,
    entry_type: []const u8,
    status: []const u8,
};

pub const Db = struct {
    handle: ?*c.sqlite3 = null,

    pub fn open(path: [*:0]const u8) !Db {
        var db = Db{};
        if (c.sqlite3_open(path, &db.handle) != c.SQLITE_OK) return error.SqliteOpenFailed;
        try db.exec(
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
        return db;
    }

    pub fn close(self: *Db) void {
        if (self.handle) |h| _ = c.sqlite3_close(h);
        self.handle = null;
    }

    pub fn exec(self: *Db, sql: [*:0]const u8) !void {
        if (c.sqlite3_exec(self.handle, sql, null, null, null) != c.SQLITE_OK) return error.SqliteExecFailed;
    }

    pub fn setConfig(self: *Db, key: [*:0]const u8, value: [*:0]const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "INSERT OR REPLACE INTO config(key,value) VALUES(?,?)", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt, 1, key, -1, c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 2, value, -1, c.SQLITE_TRANSIENT);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    pub fn getConfig(self: *Db, allocator: std.mem.Allocator, key: [*:0]const u8) !?[]const u8 {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "SELECT value FROM config WHERE key=?", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt, 1, key, -1, c.SQLITE_TRANSIENT);
        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) return null;
        const raw: [*c]const u8 = c.sqlite3_column_text(stmt, 0);
        const len: usize = @intCast(c.sqlite3_column_bytes(stmt, 0));
        return try allocator.dupe(u8, raw[0..len]);
    }

    pub fn addEntry(self: *Db, name: [*:0]const u8, original_path: [*:0]const u8, entry_type: [*:0]const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "INSERT INTO entries(name,original_path,type) VALUES(?,?,?)", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt, 1, name, -1, c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 2, original_path, -1, c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 3, entry_type, -1, c.SQLITE_TRANSIENT);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    pub fn deleteEntry(self: *Db, name: [*:0]const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "DELETE FROM entries WHERE name=?", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt, 1, name, -1, c.SQLITE_TRANSIENT);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    pub fn getAllEntries(self: *Db, allocator: std.mem.Allocator) ![]Entry {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "SELECT name,original_path,type,status FROM entries", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        var list = std.ArrayList(Entry).init(allocator);
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            try list.append(.{
                .name = try dupeCol(allocator, stmt, 0),
                .original_path = try dupeCol(allocator, stmt, 1),
                .entry_type = try dupeCol(allocator, stmt, 2),
                .status = try dupeCol(allocator, stmt, 3),
            });
        }
        return list.toOwnedSlice();
    }

    pub fn updateStatus(self: *Db, name: [*:0]const u8, status: [*:0]const u8) !void {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, "UPDATE entries SET status=?,updated_at=datetime('now') WHERE name=?", -1, &stmt, null) != c.SQLITE_OK) return error.SqlitePrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt, 1, status, -1, c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 2, name, -1, c.SQLITE_TRANSIENT);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    fn dupeCol(allocator: std.mem.Allocator, stmt: ?*c.sqlite3_stmt, col: c_int) ![]const u8 {
        const raw: [*c]const u8 = c.sqlite3_column_text(stmt, col);
        const len: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        return try allocator.dupe(u8, raw[0..len]);
    }
};
