const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        const exe = b.addExecutable(.{
            .name = "hexy",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibC();
        exe.addIncludePath(b.path("deps"));
        exe.linkLibrary(b.dependency("glfw", .{}).artifact("glfw"));
        if (builtin.os.tag == .linux) {
            exe.linkSystemLibrary("GL");
        }
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const unit_tests = b.addTest(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
        });
        unit_tests.linkLibC();
        unit_tests.addIncludePath(b.path("deps"));
        unit_tests.linkLibrary(b.dependency("glfw", .{}).artifact("glfw"));

        const run_unit_tests = b.addRunArtifact(unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }
}
