//! References:
//!     https://cran.r-project.org/doc/manuals/R-ints.html
//!     https://cran.r-project.org/doc/manuals/R-exts.html

const r = @import("r.zig");

const std = @import("std");
const testing = std.testing;

// R data types
pub usingnamespace @import("types.zig");
pub usingnamespace @import("constants.zig");

// Internal R API exposed for convenience.
// Intention is to deprecate when library is complete.
pub const internal_R_api = r;

// R memory allocators
pub const heap = @import("allocator.zig");

// R Input/Output
pub const io = @import("io.zig");

// R Errors/Warnings
pub const errors = @import("errors.zig");

test {
    testing.refAllDecls(@This());
}
