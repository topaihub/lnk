const std = @import("std");
const logging = @import("zig-logging");
const Store = @import("core/store.zig").Store;
const Vcs = @import("core/vcs.zig").Vcs;
const Fs = @import("core/fs.zig").Fs;

pub const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: Store,
    vcs: Vcs,
    fs: Fs,
    repo_dir: []const u8,
    lnk_home: []const u8,
    log: logging.SubsystemLogger,
    managed_logger: ?logging.ManagedLogger = null,

    pub fn deinit(self: *App) void {
        self.store.close();
        self.allocator.free(self.lnk_home);
        self.allocator.free(self.repo_dir);
        if (self.managed_logger) |*ml| ml.deinit();
    }
};
