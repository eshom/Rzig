//! R control flow affecting error handling and warnings

const r = @import("r.zig");

const std = @import("std");
const fmt = std.fmt;

//TODO: Support formatting messages without allocation (pre-allocate buffer?)

// pub const stop = r.Rf_error;
// pub const warning = r.Rf_warning;
pub const stopCall = r.Rf_errorcall;
pub const warningCall = r.Rf_warningcall;
pub const warningCallImmediate = r.Rf_warningcall_immediate;

/// Asserts expression. If false prints error to R managed stderr and returns
/// control flow back to R.
pub fn RAssert(ok: bool, msg: []const u8) void {
    if (!ok) {
        stop(msg);
    }
}

/// Prints error to R managed stderr and returns control flow back to R.
pub fn stop(msg: []const u8) void {
    r.Rf_error("%.*s\n", msg.len, msg.ptr);
}

/// Prints warning to R managed stderr
pub fn warning(msg: []const u8) void {
    r.Rf_warning("%.*s\n", msg.len, msg.ptr);
}
