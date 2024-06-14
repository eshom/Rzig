//! R printing functions
const r = @import("r.zig");
const std = @import("std");
const io = std.io;

// Errors are not expected on zig side (but maybe in R runtime),
// however Writer interface expects an error set.
const NoPrintError = error{
    UnexpectedError,
};

pub fn RStdoutWriter() type {
    return struct {
        const Self = @This();
        const Writer = io.GenericWriter(void, NoPrintError, writeFn);

        // R's `Rprintf` does not return number of bytes written.
        // So this function will assume all bytes sent to R's managed stdout are written.
        fn writeFn(ctx: void, data: []const u8) NoPrintError!usize {
            _ = ctx;

            const msg: [*c]const u8 = @ptrCast(data);
            r.Rprintf("%s", msg);

            return data.len;
        }

        pub fn writer() Writer {
            return .{ .context = {} };
        }
    };
}

// pub const RStdoutWriter2 = struct {
//     const Writer = io.GenericWriter(*RStdoutWriter, NoPrintError, writeFn);
//
//     // R's `Rprintf` does not return number of bytes written.
//     // So this function will assume all bytes sent to R's managed stdout are written.
//     fn writeFn(ctx: *RStdoutWriter, data: []const u8) NoPrintError!usize {
//         _ = ctx;
//
//         const msg: [*c]const u8 = @ptrCast(data);
//         r.Rprintf("%s", msg);
//
//         return data.len;
//     }
//
//     pub fn writer(self: RStdoutWriter) Writer {
//         return .{ .context = self };
//     }
// };

// /// Like `printf`, but guaranteed to print to R's stderr.
// pub const printfErr = r.REprintf;
