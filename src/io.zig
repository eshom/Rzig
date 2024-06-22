//! R printing utilities
const r = @import("r.zig");
const std = @import("std");
const io = std.io;
const math = std.math;
const testing = std.testing;

const PrintError = error{
    LengthTooBig,
};

/// Implements `std.io.GenericWriter`
/// Prints to R managed stdout
/// When writing, will only return error if string length is longer than `c_int` max size
pub fn RStdoutWriter() type {
    return struct {
        const Self = @This();
        const Writer = io.GenericWriter(void, PrintError, writeFn);

        // R's `Rprintf` does not return number of bytes written.
        // So this function will not have related saftey checks, and assume that all bytes are written to R's managed stdout.
        fn writeFn(ctx: void, data: []const u8) PrintError!usize {
            _ = ctx;

            if (data.len > math.maxInt(c_int)) {
                return PrintError.LengthTooBig;
            }

            const len: c_int = @intCast(data.len);

            // `len` is run-time known maximum string length for `data.ptr`
            r.Rprintf("%.*s", len, data.ptr);

            return data.len;
        }

        pub fn writer() Writer {
            return .{ .context = {} };
        }
    };
}

/// Implements `std.io.GenericWriter`
/// Prints to R managed stderr
/// When writing, will only return error if string length is longer than `c_int` max size
pub fn RStderrWriter() type {
    return struct {
        const Self = @This();
        const Writer = io.GenericWriter(void, PrintError, writeFn);

        fn writeFn(ctx: void, data: []const u8) PrintError!usize {
            _ = ctx;

            if (data.len > math.maxInt(c_int)) {
                return PrintError.LengthTooBig;
            }

            const len: c_int = @intCast(data.len);

            r.REprintf("%.*s", len, data.ptr);

            return data.len;
        }

        pub fn writer() Writer {
            return .{ .context = {} };
        }
    };
}

test "print to stdout and stderr" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testHelloStderr')
        \\.Call('testHello')
        \\.Call('testHelloCFormat')
    ;

    const result = try std.process.Child.run(.{
        .allocator = testing.allocator,
        .argv = &.{
            "Rscript",
            "--vanilla",
            "-e",
            code,
        },
    });

    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    const expected =
        \\Hello, Error!
        \\
    ;

    const expected2 =
        \\NULL
        \\Hello, World!
        \\NULL
        \\%d%d%sHello, World!%d%d%s
        \\NULL
        \\
    ;

    testing.expectEqualStrings(expected, result.stderr) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };

    testing.expectEqualStrings(expected2, result.stdout) catch |err| {
        std.debug.print("stdout:\n{s}\n", .{result.stdout});
        return err;
    };
}
