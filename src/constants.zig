//! R constants

const r = @import("r.zig");
const Robject = @import("types.zig").Robject;

/// Points to Rtype.NULL value (NILSXP)
pub const r_null: *Robject = &r.R_NilValue;
