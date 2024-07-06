//! Related to evaluation of R expressions
const rzig = @import("Rzig.zig");
const r = @import("r.zig");
const Robject = rzig.Robject;

pub fn eval(expr: Robject, envir: Robject) Robject {
    return r.Rf_eval(expr, envir);
}
