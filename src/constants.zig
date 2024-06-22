//! R constants

const r = @import("r.zig");
const RObject = @import("types.zig").RObject;

/// Points to Rtype.NULL value (NILSXP)
pub const r_null: *RObject = &r.R_NilValue;
