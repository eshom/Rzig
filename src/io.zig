//! R printing utilities
const std = @import("std");
const io = std.io;
const math = std.math;
const testing = std.testing;
const fmt = std.fmt;

const r = @import("r.zig");
const rzig = @import("Rzig.zig");
const errors = rzig.errors;

const Robject = rzig.Robject;
const BUFFER_SIZE = r.BUFSIZE;

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

///This should display the message, which may have multiple lines: it should be brought to the user’s attention immediately.
///Prints to R managed stderr.
pub fn showMessage(comptime format: []const u8, args: anytype) void {
    var buf: [BUFFER_SIZE]u8 = undefined;
    const msg = fmt.bufPrintZ(&buf, format, args) catch |err| blk: {
        errors.warning("Caught {!}. Formatted message too long. Using unformatted message, possibly truncated.\n", .{err});
        const minlen = @min(format.len, BUFFER_SIZE);
        break :blk format[0..minlen];
    };
    r.R_ShowMessage(msg.ptr); // Guaranteed to be null terminated by bufPrintZ()
}

test "showMessage" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testShowMessage')
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
        \\Important message:
        \\This is a test.
        \\
        \\
    ;

    try testing.expectEqualSlices(u8, expected, result.stderr);
}

/// Print R object (SEXP). Equivalent to R's `print()` function.
pub fn printValue(obj: Robject) void {
    r.Rf_PrintValue(obj);
}

test "printValue" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\invisible(.Call('testPrintValue', print(mtcars), parent.frame()))
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
        \\                     mpg cyl  disp  hp drat    wt  qsec vs am gear carb
        \\Mazda RX4           21.0   6 160.0 110 3.90 2.620 16.46  0  1    4    4
        \\Mazda RX4 Wag       21.0   6 160.0 110 3.90 2.875 17.02  0  1    4    4
        \\Datsun 710          22.8   4 108.0  93 3.85 2.320 18.61  1  1    4    1
        \\Hornet 4 Drive      21.4   6 258.0 110 3.08 3.215 19.44  1  0    3    1
        \\Hornet Sportabout   18.7   8 360.0 175 3.15 3.440 17.02  0  0    3    2
        \\Valiant             18.1   6 225.0 105 2.76 3.460 20.22  1  0    3    1
        \\Duster 360          14.3   8 360.0 245 3.21 3.570 15.84  0  0    3    4
        \\Merc 240D           24.4   4 146.7  62 3.69 3.190 20.00  1  0    4    2
        \\Merc 230            22.8   4 140.8  95 3.92 3.150 22.90  1  0    4    2
        \\Merc 280            19.2   6 167.6 123 3.92 3.440 18.30  1  0    4    4
        \\Merc 280C           17.8   6 167.6 123 3.92 3.440 18.90  1  0    4    4
        \\Merc 450SE          16.4   8 275.8 180 3.07 4.070 17.40  0  0    3    3
        \\Merc 450SL          17.3   8 275.8 180 3.07 3.730 17.60  0  0    3    3
        \\Merc 450SLC         15.2   8 275.8 180 3.07 3.780 18.00  0  0    3    3
        \\Cadillac Fleetwood  10.4   8 472.0 205 2.93 5.250 17.98  0  0    3    4
        \\Lincoln Continental 10.4   8 460.0 215 3.00 5.424 17.82  0  0    3    4
        \\Chrysler Imperial   14.7   8 440.0 230 3.23 5.345 17.42  0  0    3    4
        \\Fiat 128            32.4   4  78.7  66 4.08 2.200 19.47  1  1    4    1
        \\Honda Civic         30.4   4  75.7  52 4.93 1.615 18.52  1  1    4    2
        \\Toyota Corolla      33.9   4  71.1  65 4.22 1.835 19.90  1  1    4    1
        \\Toyota Corona       21.5   4 120.1  97 3.70 2.465 20.01  1  0    3    1
        \\Dodge Challenger    15.5   8 318.0 150 2.76 3.520 16.87  0  0    3    2
        \\AMC Javelin         15.2   8 304.0 150 3.15 3.435 17.30  0  0    3    2
        \\Camaro Z28          13.3   8 350.0 245 3.73 3.840 15.41  0  0    3    4
        \\Pontiac Firebird    19.2   8 400.0 175 3.08 3.845 17.05  0  0    3    2
        \\Fiat X1-9           27.3   4  79.0  66 4.08 1.935 18.90  1  1    4    1
        \\Porsche 914-2       26.0   4 120.3  91 4.43 2.140 16.70  0  1    5    2
        \\Lotus Europa        30.4   4  95.1 113 3.77 1.513 16.90  1  1    5    2
        \\Ford Pantera L      15.8   8 351.0 264 4.22 3.170 14.50  0  1    5    4
        \\Ferrari Dino        19.7   6 145.0 175 3.62 2.770 15.50  0  1    5    6
        \\Maserati Bora       15.0   8 301.0 335 3.54 3.570 14.60  0  1    5    8
        \\Volvo 142E          21.4   4 121.0 109 4.11 2.780 18.60  1  1    4    2
        \\
    ;

    try testing.expectEqualStrings(expected, result.stdout);
}
