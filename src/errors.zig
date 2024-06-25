//! R control flow affecting error handling and warnings

const r = @import("r.zig");

const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;

pub const ERR_BUF_SIZE = 1000; // undocumented. Seems like errors are truncated to this value from testing.

pub const stopCall = r.Rf_errorcall;
pub const warningCall = r.Rf_warningcall;
pub const warningCallImmediate = r.Rf_warningcall_immediate;

/// Asserts expression. If false prints error to R managed stderr and returns
/// control flow back to R.
pub fn RAssert(ok: bool, msg: []const u8) void {
    if (!ok) {
        stop("{s}\n", .{msg});
    }
}

/// Prints formatted error message to R managed stderr and returns control flow back to R.
pub fn stop(comptime format: []const u8, args: anytype) void {
    r.R_CheckStack2(ERR_BUF_SIZE);
    var buf: [ERR_BUF_SIZE]u8 = undefined;

    const msg = fmt.bufPrint(&buf, format, args) catch |err| {
        const err_msg = @errorName(err);
        r.Rf_warning("Format string too long. Caught: %.*s\n", err_msg.len, err_msg.ptr);
        r.Rf_error("%.*s", format.len, format.ptr);
        unreachable;
    };

    r.Rf_error("%.*s", msg.len, msg.ptr);
}

test "stop" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testStop')
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
        \\Error: Test error message
        \\Execution halted
        \\
    ;

    try testing.expectEqualSlices(u8, expected, result.stderr);
}

test "stop2" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testStop2')
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

    const error_message = "Error: " ++ "." ** (ERR_BUF_SIZE - 7) ++ "\n";
    const warning_message = "In addition: Warning message:\nFormat string too long. Caught: " ++ "NoSpaceLeft \n" ++
        \\Execution halted
        \\
    ;

    try testing.expectEqualSlices(u8, error_message ++ warning_message, result.stderr);
}

/// Prints warning to R managed stderr
pub fn warning(msg: []const u8) void {
    r.Rf_warning("%.*s\n", msg.len, msg.ptr);
}
