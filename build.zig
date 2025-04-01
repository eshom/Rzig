const std = @import("std");

const GeneratedFile = std.Build.GeneratedFile;

pub fn build(b: *std.Build) !void {
    const make = b.findProgram(
        &.{"make"},
        &.{},
    ) catch std.debug.panic("could not find `make`. It's required to build R.", .{});

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const rsource = b.dependency("rsource", .{});

    const configure_run = rsource.builder.addSystemCommand(
        &.{
            "./configure",
            "--enable-R-shlib", // builds the shared library
            "--disable-R-profiling",
            "--disable-java",
            "--disable-byte-compiled-packages",
            "--disable-byte-compiled-packages",
            "--disable-shared",
            "--disable-nls",
            "--disable-openmp",
            "--without-recommended-packages",
            "--without-readline",
            "--without-tcltk",
            "--without-cairo",
            "--without-libpng",
            "--without-jpeglib",
            "--without-libtiff",
            "--without-ICU",
            "--without-x",
            "--without-libdeflate-compression",
        },
    );
    b.step("configure", "Run configure for R source").dependOn(&configure_run.step);

    const make_run = rsource.builder.addSystemCommand(&.{make});
    const make_clean = rsource.builder.addSystemCommand(&.{ make, "clean" });
    b.step("make-clean", "Run `make clean` for R source").dependOn(&make_clean.step);

    const libr_install = b.addInstallLibFile(rsource.builder.path("lib/libR.so"), "libR.so");
    libr_install.step.dependOn(&make_run.step);
    const librblas_install = b.addInstallLibFile(rsource.builder.path("lib/libRblas.so"), "libRblas.so");
    librblas_install.step.dependOn(&make_run.step);

    const libr = b.step("libR", "Build R library from source. Run `zig build configure` first");
    libr.dependOn(&libr_install.step);
    libr.dependOn(&librblas_install.step);

    // Zig public module, to be used by the package manager
    const rzig_mod = b.addModule("Rzig", .{
        .root_source_file = b.path("src/Rzig.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .pic = true,
    });
    rzig_mod.addLibraryPath(b.path("zig-out/lib"));
    rzig_mod.linkSystemLibrary("R", .{ .use_pkg_config = .no });
    rzig_mod.linkSystemLibrary("Rblas", .{ .use_pkg_config = .no });

    const rtests_mod = b.createModule(.{
        .root_source_file = b.path("tests/Rtests.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .imports = &.{
            .{ .name = "Rzig", .module = rzig_mod },
        },
    });

    // R lib compiled by zig for tests
    const rtests = b.addLibrary(.{
        .name = "Rtests",
        .linkage = .dynamic,
        .root_module = rtests_mod,
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
        .root_module = rzig_mod,
        .filter = b.option([]const u8, "test-filter", "String to filter tests by"),
    });

    const run_rzig_tests = b.addRunArtifact(rzig_tests);
    run_rzig_tests.setEnvironmentVariable("LD_LIBRARY_PATH", "zig-out/lib");
    run_rzig_tests.has_side_effects = true; // tests call child R process

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&rtests_install.step);
    test_step.dependOn(&run_rzig_tests.step);

    // LSP build check
    const check = b.step("check", "Check compile errors");
    check.dependOn(&rzig_tests.step);
    check.dependOn(&rtests.step);
}
