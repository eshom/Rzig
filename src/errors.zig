//! R control flow affecting error handling and warnings

const r = @import("r.zig");

pub const stop = r.Rf_error;
pub const warning = r.Rf_warning;
pub const stopCall = r.Rf_errorcall;
pub const warningCall = r.Rf_warningcall;
pub const warningCallImmediate = r.Rf_warningcall_immediate;

pub fn RAssert(ok: bool, str: []const u8) void {
    if (!ok) {
        stop("Assertion error: %.*s\n", str.len, str.ptr);
    }
}

// pub fn stop() callconv(.C) {
//
// }
