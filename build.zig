const std = @import("std");

fn exists(path: []const u8) bool {
    _ = std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch return false;
    return true;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const gbzg = b.addExecutable(.{
        .name = "gbzg",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gbzg.linkSystemLibrary("sixel");
    b.installArtifact(gbzg);

    const zdb = b.addExecutable(.{
        .name = "zdb",
        .root_source_file = .{ .path = "src/zdb.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });
    b.installArtifact(zdb);

    const run_cmd = b.addRunArtifact(gbzg);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
