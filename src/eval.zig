//! Related to evaluation of R expressions

const r = @import("r.zig");
const rzig = @import("Rzig.zig");

const Robject = rzig.Robject;
pub const ExecFun = *const fn (*anyopaque) callconv(.C) void;

pub const Error = error{
    ErrorOccured,
};

pub fn toplevelExec(fun: ExecFun, data: *anyopaque) bool {
    const normal = r.R_ToplevelExec(fun, data);
    return switch (normal) {
        .TRUE => true,
        .FALSE => false,
    };
}

pub fn eval(expr: Robject, envir: Robject) Robject {
    return r.Rf_eval(expr, envir);
}

pub fn tryEval(expr: Robject, env: Robject) Error!Robject {
    var errno: c_int = -1;
    const maybe = r.R_tryEval(expr, env, &errno);

    // Do the error values mean anything, or is it binary?
    switch (errno) {
        0 => return maybe.?,
        else => return Error.ErrorOccured,
    }
}

pub fn tryEvalSilent(expr: Robject, env: Robject) Error!Robject {
    var errno: c_int = -1;
    const maybe = r.R_tryEvalSilent(expr, env, &errno);

    switch (errno) {
        0 => return maybe.?,
        else => return Error.ErrorOccured,
    }
}
