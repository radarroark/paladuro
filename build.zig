const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        const exe = b.addExecutable(.{
            .name = "paladuro",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        addDeps(b, exe);
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
        addDeps(b, unit_tests);

        const run_unit_tests = b.addRunArtifact(unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }
}

fn addDeps(b: *std.Build, step: *std.Build.Step.Compile) void {
    step.linkLibC();
    step.addIncludePath(b.path("deps/include"));
    step.linkLibrary(b.dependency("glfw", .{}).artifact("glfw"));
    switch (builtin.os.tag) {
        .linux => step.linkSystemLibrary("GL"),
        else => @panic("must link opengl for this OS"),
    }
}
