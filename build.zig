const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_module = b.dependency("vulkan", .{
        .registry = std.Build.LazyPath{
            .cwd_relative = b.graph.environ_map.get("VULKAN_REGISTRY_XML") orelse {
                std.debug.panic("not in nix devshell with VULKAN_REGISTRY_XML env var", .{});
            },
        },
    }).module("vulkan-zig");

    const deletion_queue_module = b.addModule("DeletionQueue", .{
        .root_source_file = b.path("DeletionQueue/deletion_queue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const window_module = b.addModule("Window", .{
        .root_source_file = b.path("Window/window.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const renderer_module = b.addModule("Renderer", .{
        .root_source_file = b.path("Renderer/renderer.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    renderer_module.addImport("Vulkan", vulkan_module);
    renderer_module.addImport("DeletionQueue", deletion_queue_module);
    renderer_module.addImport("Window", window_module);

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("Src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    exe.root_module.addImport("Vulkan", vulkan_module);
    exe.root_module.addImport("DeletionQueue", deletion_queue_module);
    exe.root_module.addImport("Window", window_module);
    exe.root_module.addImport("Renderer", renderer_module);

    exe.root_module.linkSystemLibrary("SDL3", .{});

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run executable");
    run_step.dependOn(&run.step);
}
