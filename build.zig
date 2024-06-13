const std = @import("std");

//TODO: Check R > 4.4.0 is installed

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Zig library module, imported by tests
    // This also serves as an example of how to import this library
    const Rzig = b.addModule("Rzig", .{
        .root_source_file = .{
            .cwd_relative = "src/Rzig.zig",
        },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    //TODO: figure out paths for other OS and linux distros
    Rzig.addLibraryPath(.{ .cwd_relative = "/usr/lib64/R/lib/" });
    Rzig.addSystemIncludePath(.{ .cwd_relative = "/usr/lib64/R/include/" });
    Rzig.linkSystemLibrary("R", .{});

    // R lib compiled by zig for tests
    const Rtests = b.addSharedLibrary(.{
        .name = "Rtests",
        .root_source_file = b.path("examples/src/Rtests.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    Rtests.linkLibC();
    Rtests.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib64/R/lib/" });
    Rtests.root_module.addSystemIncludePath(.{ .cwd_relative = "/usr/lib64/R/include/" });
    Rtests.root_module.linkSystemLibrary("R", .{});
    Rtests.root_module.addImport("Rzig", Rzig);

    const Rtests_install = b.addInstallArtifact(
        Rtests,
        .{
            .dest_dir = .{
                .override = .{ .custom = "tests/lib/" },
            },
        },
    );

    // General tests that depend on Rtests library
    const Rzig_tests = b.addTest(.{
        .root_source_file = b.path("src/Rzig.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Include and Link R
    Rzig_tests.linkLibC(); // for libR
    Rzig_tests.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib64/R/lib/" });
    Rzig_tests.root_module.addSystemIncludePath(.{ .cwd_relative = "/usr/lib64/R/include/" });
    Rzig_tests.root_module.linkSystemLibrary("R", .{});

    const run_Rzig_tests = b.addRunArtifact(Rzig_tests);
    run_Rzig_tests.has_side_effects = true; // tests call child R process

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&Rtests_install.step);
    test_step.dependOn(&run_Rzig_tests.step);
}
