const std = @import("std");

const GeneratedFile = std.Build.GeneratedFile;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Zig public module, to be used by the package manager
    const rzig = b.addModule("Rzig", .{
        .root_source_file = b.path("src/Rzig.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    rzig.linkSystemLibrary("libR", .{ .use_pkg_config = .force });

    const rtests_mod = b.createModule(.{
        .root_source_file = b.path("tests/Rtests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "Rzig", .module = rzig },
        },
    });
    rtests_mod.linkSystemLibrary("libR", .{ .use_pkg_config = .force });

    // R lib compiled by zig for tests
    const rtests = b.addSharedLibrary(.{
        .name = "Rtests",
        .root_module = rtests_mod,
        .pic = true,
    });

    const rtests_install = b.addInstallArtifact(
        rtests,
        .{
            .dest_dir = .{
                .override = .{ .custom = "tests/lib/" },
            },
        },
    );

    // General tests that depend on Rtests library
    const rzig_tests = b.addTest(.{
        .root_module = rzig,
        .filter = b.option([]const u8, "test-filter", "String to filter tests by"),
    });

    const run_rzig_tests = b.addRunArtifact(rzig_tests);
    run_rzig_tests.has_side_effects = true; // tests call child R process

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&rtests_install.step);
    test_step.dependOn(&run_rzig_tests.step);

    // LSP build check
    const check = b.step("check", "Check if Rzig compiles");
    check.dependOn(&rzig_tests.step);
    check.dependOn(&rtests.step);
}
