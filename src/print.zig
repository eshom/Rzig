//! R printing functions
const r = @import("r.zig");
const std = @import("std");
const io = std.io;
const math = std.math;

const PrintError = error{
    LengthTooBig,
};

/// Writer interface does not guarantee null terminated string
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

            r.Rprintf("%.*s", len, data.ptr);

            return data.len;
        }

        pub fn writer() Writer {
            return .{ .context = {} };
        }
    };
}

// /// Like `printf`, but guaranteed to print to R's stderr.
// pub const printfErr = r.REprintf;
