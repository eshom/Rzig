//! R control flow affecting error handling and warnings

const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;

const r = @import("r.zig");
const rzig = @import("Rzig.zig");

const Robject = rzig.Robject;
pub const ERR_BUF_SIZE = 1000; // undocumented. Seems like errors are truncated to this value from testing.

/// Asserts expression. If false prints error to R managed stderr and returns
/// control flow back to R.
pub fn RAssert(ok: bool, msg: []const u8) void {
    if (!ok) {
        stop("{s}\n", .{msg});
    }
}

/// Prints formatted error message to R managed stderr and returns control flow back to R.
///
/// It's safe and recommended to use `unreachable` after this call.
pub fn stop(comptime format: []const u8, args: anytype) void {
    r.R_CheckStack2(ERR_BUF_SIZE);
    var buf: [ERR_BUF_SIZE]u8 = undefined;

    const msg = fmt.bufPrint(&buf, format, args) catch |err| {
        const err_msg = @errorName(err);
        r.Rf_warning("Message too long. Caught: %.*s\n", err_msg.len, err_msg.ptr);
        r.Rf_error("%.*s", format.len, format.ptr);
        unreachable;
    };

    r.Rf_error("%.*s", msg.len, msg.ptr);
    unreachable;
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
    const warning_message = "In addition: Warning message:\nMessage too long. Caught: " ++ "NoSpaceLeft \n" ++
        \\Execution halted
        \\
    ;

    try testing.expectEqualSlices(u8, error_message ++ warning_message, result.stderr);
}

/// Prints warning to R managed stderr
pub fn warning(comptime format: []const u8, args: anytype) void {
    r.R_CheckStack2(ERR_BUF_SIZE);
    var buf: [ERR_BUF_SIZE]u8 = undefined;

    const msg = fmt.bufPrint(&buf, format, args) catch |err| blk: {
        const err_msg = @errorName(err);
        r.Rf_warning("Message too long. Skipping format arguments. Caught: %.*s\n", err_msg.len, err_msg.ptr);
        const minlen = @min(format.len, ERR_BUF_SIZE);
        break :blk "Format: " ++ format[0..minlen];
    };

    r.Rf_warning("%.*s", msg.len, msg.ptr);
}

test "warning" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testWarning')
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
        \\Warning message:
        \\Test warning message 1234 
        \\
    ;

    try testing.expectEqualSlices(u8, expected, result.stderr);
}

test "warning2" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testWarning2')
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

    const warning1 = "Warning messages:\n1: Message too long. Skipping format arguments. Caught: " ++ "NoSpaceLeft \n";
    const warning2 = "2: Format: {s}{s}";

    const expected = warning1 ++ warning2 ++ " \n";

    try testing.expectEqualSlices(u8, expected, result.stderr);
}

/// Prints formatted error message to R managed stderr and returns control flow back to R.
/// R call information is included in the error message.
/// If call = r_null.*, the effect is the same as stop().
///
/// It's safe and recommended to use `unreachable` after this call.
pub fn stopCall(call: Robject, comptime format: []const u8, args: anytype) void {
    r.R_CheckStack2(ERR_BUF_SIZE);
    var buf: [ERR_BUF_SIZE]u8 = undefined;

    const msg = fmt.bufPrint(&buf, format, args) catch |err| {
        //TODO: Add test for this branch
        const err_msg = @errorName(err);
        r.Rf_warning("Message too long. Caught: %.*s\n", err_msg.len, err_msg.ptr);
        r.Rf_errorcall(call, "%.*s", format.len, format.ptr);
        unreachable;
    };

    r.Rf_errorcall(call, "%.*s", msg.len, msg.ptr);
    unreachable;
}

test "stopCall" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\f <- function(x = 1:10) { cumsum(x) }
        \\.Call('testStopCall', f)
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
        \\Error in function (x = 1:10)  : Test error message 1234
        \\Calls: .Call
        \\Execution halted
        \\
    ;

    try testing.expectEqualSlices(u8, expected, result.stderr);
}

/// Prints formatted error message to R managed stderr.
/// R call information is included in the error message.
/// If call = r_null.*, the effect is the same as warning().
pub fn warningCall(call: Robject, comptime format: []const u8, args: anytype) void {
    r.R_CheckStack2(ERR_BUF_SIZE);
    var buf: [ERR_BUF_SIZE]u8 = undefined;

    const msg = fmt.bufPrint(&buf, format, args) catch |err| blk: {
        //TODO: Add test for this branch
        const err_msg = @errorName(err);
        r.Rf_warning("Message too long. Caught: %.*s\n", err_msg.len, err_msg.ptr);
        const minlen = @min(format.len, ERR_BUF_SIZE);
        break :blk "Format: " ++ format[0..minlen];
    };

    r.Rf_warningcall(call, "%.*s", msg.len, msg.ptr);
}

test "warningCall" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\f <- function(x = 1:10) { cumsum(x) }
        \\.Call('testWarningCall', f)
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
        \\Warning message:
        \\In function (x = 1:10)  : Test error message 4321
        \\
        \\
    ;

    try testing.expectEqualSlices(u8, expected, result.stderr);
}

/// Prints formatted error message to R managed stderr.
/// R call information is included in the error message.
/// If call = r_null.*, the effect is the same as warning().
///
/// Compared to warningCall() this version does not include "Warning message(s) header"
pub fn warningCallImmediate(call: Robject, comptime format: []const u8, args: anytype) void {
    r.R_CheckStack2(ERR_BUF_SIZE);
    var buf: [ERR_BUF_SIZE]u8 = undefined;

    const msg = fmt.bufPrint(&buf, format, args) catch |err| blk: {
        //TODO: Add test for this branch
        const err_msg = @errorName(err);
        r.Rf_warning("Message too long. Caught: %.*s\n", err_msg.len, err_msg.ptr);
        const minlen = @min(format.len, ERR_BUF_SIZE);
        break :blk "Format: " ++ format[0..minlen];
    };

    r.Rf_warningcall_immediate(call, "%.*s", msg.len, msg.ptr);
}

test "warningCallImmediate" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\f <- function(x = 1:10) { cumsum(x) }
        \\.Call('testWarningCallImmediate', f)
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
        \\Warning in function (x = 1:10)  : Test error message 654321
        \\
        \\
    ;

    try testing.expectEqualSlices(u8, expected, result.stderr);
}
