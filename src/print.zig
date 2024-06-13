//! R printing functions

const r = @import("r.zig");

/// Like `printf`, but guaranteed to print to R's output.
pub const printf = r.Rprintf;
/// Like `printf`, but guaranteed to print to R's stderr.
pub const printfErr = r.REprintf;
