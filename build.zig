const std = @import("std");

const GeneratedFile = std.Build.GeneratedFile;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const rsource = b.dependency("rsource", .{});

    const configure = configureCommand(b, rsource);

    const config_write = b.addWriteFiles();
    config_write.step.dependOn(&configure.step);
    const config_status = config_write.addCopyFile(rsource.builder.path("config.status"), "config.status");

    b.step("make-clean", "Run `make clean` for R source cache")
        .dependOn(&makeCommand(b, rsource, "clean").step);

    const make = makeCommand(b, rsource, null);
    make.addFileInput(config_status);
    _ = make.captureStdOut();
    make.step.dependOn(&config_write.step);

    const libnames: [3][]const u8 = .{ "libR.so", "libRblas.so", "libRlapack.so" };
    const copyfiles, const artifacts = copyMakeArtifacts(
        b,
        .{
            rsource.builder.path("lib/" ++ libnames[0]),
            rsource.builder.path("lib/" ++ libnames[1]),
            rsource.builder.path("lib/" ++ libnames[2]),
        },
    );
    copyfiles.step.dependOn(&make.step);

    for (artifacts, libnames) |art, lib| {
        const install = b.addInstallLibFile(art, lib);
        install.step.dependOn(&copyfiles.step);
        b.getInstallStep().dependOn(&install.step);
    }

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

    const rtests = addRTestLibInstall(b, .{ &target, &optimize }, rzig_mod);
    rtests.step.dependOn(b.getInstallStep());

    // General tests that depend on Rtests library
    const rzig_tests = b.addTest(.{
        .root_module = rzig_mod,
        .filter = b.option([]const u8, "test-filter", "String to filter tests by"),
    });

    // TODO: Move R executable to zig-out, and have tests call that
    // istead of having this system dependency.

    const run_tests = b.addRunArtifact(rzig_tests);
    run_tests.setEnvironmentVariable("LD_LIBRARY_PATH", "zig-out/lib");
    run_tests.has_side_effects = true; // tests call R process

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&rtests.step);
    test_step.dependOn(&run_tests.step);

    // LSP build check
    const check = b.step("check", "Check compile errors");
    check.dependOn(&rzig_tests.step);
    check.dependOn(&rtests.artifact.step);
}

fn configureCommand(b: *std.Build, dep: *std.Build.Dependency) *std.Build.Step.Run {
    const configure = dep.builder.addSystemCommand(&.{"./configure"});
    configure.addArgs(
        &.{
            "--enable-R-shlib", // builds the R shared library
            "--enable-BLAS-shlib", // builds the Rblas shared library
            "--disable-R-profiling",
            "--disable-java",
            "--disable-byte-compiled-packages",
            "--disable-byte-compiled-packages",
            "--disable-shared",
            "--disable-nls",
            "--disable-R-framework",
            "--disable-openmp",
            "--disable-rpath",
            "--enable-year2038",
            "--without-recommended-packages",
            "--without-readline",
            "--without-aqua",
            "--without-tcltk",
            "--without-cairo",
            "--without-libpng",
            "--without-jpeglib",
            "--without-libtiff",
            "--without-system-tre",
            "--without-ICU",
            "--without-x",
            "--without-libdeflate-compression",
            "--without-libpth-prefix",
            "--without-included-gettext",
            "--without-newAccelerate",
        },
    );
    configure.setEnvironmentVariable("MAKE", "make -j6");
    const force_conf = b.option(bool, "force-configure", "Force configure to re-run") orelse false;
    if (!force_conf) {
        _ = configure.captureStdOut(); // hack to make configure run once
    }
    return configure;
}

fn makeCommand(
    b: *std.Build,
    dep: *std.Build.Dependency,
    subcmd: ?[]const u8,
) *std.Build.Step.Run {
    const make_prog = b.findProgram(
        &.{"make"},
        &.{},
    ) catch std.debug.panic("could not find `make`. It's required to build R.", .{});

    const make = if (subcmd) |sub| withsub: {
        break :withsub dep.builder.addSystemCommand(&.{ make_prog, sub });
    } else nosub: {
        break :nosub dep.builder.addSystemCommand(&.{make_prog});
    };

    return make;
}

fn copyMakeArtifacts(
    b: *std.Build,
    artifacts: [3]std.Build.LazyPath,
) struct { *std.Build.Step.WriteFile, [3]std.Build.LazyPath } {
    const lib1, const lib2, const lib3 = artifacts;
    const awf = b.addWriteFiles();
    const out1 = awf.addCopyFile(lib1, lib1.getDisplayName());
    const out2 = awf.addCopyFile(lib2, lib2.getDisplayName());
    const out3 = awf.addCopyFile(lib3, lib3.getDisplayName());
    return .{ awf, .{ out1, out2, out3 } };
}

fn addRTestLibInstall(
    b: *std.Build,
    target_optimize: struct {
        *const std.Build.ResolvedTarget,
        *const std.builtin.OptimizeMode,
    },
    rmod: *std.Build.Module,
) *std.Build.Step.InstallArtifact {
    const rtests_mod = b.createModule(.{
        .root_source_file = b.path("tests/Rtests.zig"),
        .target = target_optimize[0].*,
        .optimize = target_optimize[1].*,
        .pic = true,
        .imports = &.{
            .{ .name = "Rzig", .module = rmod },
        },
    });

    const rtests = b.addLibrary(.{
        .name = "Rtests",
        .linkage = .dynamic,
        .root_module = rtests_mod,
    });

    return b.addInstallArtifact(
        rtests,
        .{
            .dest_dir = .{
                .override = .{ .custom = "tests/lib/" },
            },
        },
    );
}
