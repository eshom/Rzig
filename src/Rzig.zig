//! References:
//!     https://cran.r-project.org/doc/manuals/R-ints.html
//!     https://cran.r-project.org/doc/manuals/R-exts.html

const r = @import("r.zig");

const std = @import("std");
const testing = std.testing;

// R data types
pub usingnamespace @import("types.zig");
pub usingnamespace @import("constants.zig");

// R memory allocators
pub const heap = @import("allocator.zig");

// R Input/Output
pub const io = @import("io.zig");

// R Errors/Warnings
pub const errors = @import("errors.zig");

// Evaluation of R code
pub const eval = @import("eval.zig");

// GC protect
pub const gc = @import("gc.zig");

// R Vector handling
pub const vec = @import("vectors.zig");

// String handling
pub const strings = @import("strings.zig");

test {
    testing.refAllDecls(@This());
}
