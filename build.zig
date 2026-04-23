const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 日志组件（本地依赖）
    const logging_module = b.addModule("zig-logging", .{
        .root_source_file = b.path("../zig-logging/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "lnk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addCSourceFile(.{
        .file = b.path("deps/sqlite3/sqlite3.c"),
        .flags = &.{ "-DSQLITE_OMIT_LOAD_EXTENSION", "-DSQLITE_THREADSAFE=0" },
    });
    exe.root_module.addIncludePath(b.path("deps/sqlite3"));
    exe.root_module.link_libc = true;
    exe.root_module.addImport("zig-logging", logging_module);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run lnk");
    run_step.dependOn(&run_cmd.step);
}
