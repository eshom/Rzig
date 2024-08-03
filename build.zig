const std = @import("std");
const heap = std.heap;
const process = std.process;
const mem = std.mem;
const io = std.io;

const GeneratedFile = std.Build.GeneratedFile;

//TODO: Move R version check to examples
//
// const SemanticVersion = std.SemanticVersion;
// const MINIMUM_R_VERSION = SemanticVersion.parse("4.4.0") catch @compileError("Error parsing minimum R version.");
//
// const RVersionError = error{
//     UnsupportedRVersion,
// };

// fn checkRVersion() RVersionError!void {
//     const version = process.Child.run(.{
//         .allocator = heap.page_allocator,
//         .argv = &.{
//             "Rscript",
//             "--version",
//         },
//     }) catch @panic("Error while runnning `Rscript --version`. Is R installed in your system?");
//
//     defer heap.page_allocator.free(version.stdout);
//     defer heap.page_allocator.free(version.stderr);
//
//     var version_string_it = mem.tokenizeScalar(u8, version.stdout, ' ');
//     var version_string: []const u8 = undefined;
//
//     const stderr = io.getStdErr().writer();
//
//     for (0..4) |_| {
//         version_string = version_string_it.next() orelse {
//             stderr.print("Stderr:\n{s}\nStdout:\n{s}\n", .{ version.stderr, version.stdout }) catch @panic("Unable to print error message.");
//             @panic("Unexpected version string. Is R installed in your system?");
//         };
//     }
//
//     const version_found = SemanticVersion.parse(version_string) catch @panic("Unable to parse R version string. Is R installed in your system?");
//     if (version_found.order(MINIMUM_R_VERSION).compare(.lt)) {
//         stderr.print("Rzig supports R >= {}, found in system R {}\n", .{ MINIMUM_R_VERSION, version_found }) catch @panic("Unable to print error message.");
//         return RVersionError.UnsupportedRVersion;
//     }
// }

pub fn build(b: *std.Build) !void {
    // try checkRVersion();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Zig public module, to be used by the package manager
    const Rzig = b.addModule("Rzig", .{
        .root_source_file = b.path("src/Rzig.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    Rzig.linkSystemLibrary("libR", .{ .use_pkg_config = .force });

    // Zig private module, used by tests
    const _Rzig = b.createModule(.{
        .root_source_file = b.path("src/Rzig.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    _Rzig.linkSystemLibrary("libR", .{ .use_pkg_config = .force });

    // R lib compiled by zig for tests
    const Rtests = b.addSharedLibrary(.{
        .name = "Rtests",
        .root_source_file = b.path("tests/Rtests.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    Rtests.linkSystemLibrary2("libR", .{ .use_pkg_config = .force });
    Rtests.root_module.addImport("Rzig", _Rzig);

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
        .filter = b.option([]const u8, "test-filter", "String to filter tests by"),
    });

    // Include and Link R (pkg-config dependency)
    Rzig_tests.linkSystemLibrary2("libR", .{ .use_pkg_config = .force });

    const run_Rzig_tests = b.addRunArtifact(Rzig_tests);
    run_Rzig_tests.has_side_effects = true; // tests call child R process

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&Rtests_install.step);
    test_step.dependOn(&run_Rzig_tests.step);

    // LSP build check
    const Rzig_check = b.addStaticLibrary(.{
        .name = "Rzig_check",
        .root_source_file = b.path("src/Rzig.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    Rzig_check.linkSystemLibrary2("libR", .{ .use_pkg_config = .force });
    const check = b.step("check", "Check if Rzig compiles");
    // check.dependOn(&Rzig_check.step);
    check.dependOn(&Rzig_tests.step);
    check.dependOn(&Rtests.step);

    // const Rzig_docs_lib = b.addStaticLibrary(.{
    //     .name = "Rzig_docs",
    //     .target = target,
    //     .optimize = .Debug,
    //     .root_source_file = b.path("src/Rzig.zig"),
    //     .link_libc = true,
    // });
    //
    // Rzig_docs_lib.linkSystemLibrary2("libR", .{ .use_pkg_config = .force });
    // const Rzig_docs_step = b.step("docs", "Generate docs");
    //
    // const Rzig_docs = Rzig_docs_lib.getEmittedDocs();
    // Rzig_docs_step.dependOn(&b.addInstallDirectory(.{
    //     .source_dir = Rzig_docs,
    //     .install_dir = .prefix,
    //     .install_subdir = "doc",
    // }).step);
}
