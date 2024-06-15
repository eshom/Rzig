//! References:
//!     https://cran.r-project.org/doc/manuals/R-ints.html
//!     https://cran.r-project.org/doc/manuals/R-exts.html

const r = @import("r.zig");

const std = @import("std");
const testing = std.testing;

// R data types
pub usingnamespace @import("types.zig");

// Internal R API exposed for convenience.
// Intention is to deprecate when library is complete.
pub const internal_R_api = r;

// R memory allocators
pub const heap = @import("allocator.zig");
pub const io = @import("io.zig");
pub const errors = @import("errors.zig");

test {
    _ = @import("allocator.zig");
    _ = @import("io.zig");
}
