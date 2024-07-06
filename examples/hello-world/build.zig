const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const Rzig = b.dependency("Rzig", .{
        .target = target,
        .optimize = optimize,
    });

    const hello = b.addSharedLibrary(.{
        .name = "hello",
        .root_source_file = b.path("src/hello.zig"),
        .link_libc = true,
        .pic = true,
        .target = target,
        .optimize = optimize,
    });

    hello.linkSystemLibrary2("libR", .{ .use_pkg_config = .force });
    hello.root_module.addImport("Rzig", Rzig.module("Rzig"));

    b.installArtifact(hello);
}
