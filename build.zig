const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const renderer_module = b.addModule("Renderer", .{
        .root_source_file = b.path("Renderer/renderer.zig"),
        .target = target,
        .optimize = optimize,
    });

    // const tests = b.addTest(.{ .name = "tests", .root_module = b.createModule(.{
    //     .root_source_file = b.path("src/tests.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // }) });

    // Test executable
    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("Src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // tests.root_module.addImport("Compt", compt_module);
    exe.root_module.addImport("Renderer", renderer_module);

    b.installArtifact(exe);

    // const run_test = b.addRunArtifact(tests);
    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_test.step);

    const run = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run executable");
    run_step.dependOn(&run.step);
}
