//! R types and coercison functions

const std = @import("std");
const math = std.math;
const mem = std.mem;

const r = @import("r.zig");
const constants = @import("constants.zig");

const r_null = constants.r_null;

/// General purpose R object (SEXP).
/// Must use R API functions to access values and coerce to other types.
pub const Robject = r.Sexp;

pub const Rboolean = enum(c_uint) {
    False = 0,
    True = 1,
};

// NOTE: complex not supported see https://github.com/ziglang/zig/issues/16278
// TODO: Use an opaque pointer to support complex
//
// const r_legacy_complex = @hasDecl(r, "R_LEGACY_RCOMPLEX");
// pub const RComplex = if (r_legacy_complex)
// out: {
//     break :out extern struct {
//         r: f64,
//         i: f64,
//     };
// } else out: {
//     break :out extern union {
//         anon: extern struct {
//             r: f64,
//             i: f64,
//         },
//         private_data_c: [2]f64,
//     };
// };

///no   SEXPTYPE      Description
///0    NILSXP        NULL
///1    SYMSXP        symbols
///2    LISTSXP       pairlists
///3    CLOSXP        closures
///4    ENVSXP        environments
///5    PROMSXP       promises
///6    LANGSXP       language objects
///7    SPECIALSXP    special functions
///8    BUILTINSXP    builtin functions
///9    CHARSXP       internal character strings
///10   LGLSXP        logical vectors
///13   INTSXP        integer vectors
///14   REALSXP       numeric vectors
///15   CPLXSXP       complex vectors
///16   STRSXP        character vectors
///17   DOTSXP        dot-dot-dot object
///18   ANYSXP        make “any” args work
///19   VECSXP        list (generic vector)
///20   EXPRSXP       expression vector
///21   BCODESXP      byte code
///22   EXTPTRSXP     external pointer
///23   WEAKREFSXP    weak reference
///24   RAWSXP        raw vector
///25   OBJSXP        objects not of simple type
///
/// More details in https://cran.r-project.org/doc/manuals/R-ints.html#The-_0027data_0027
pub const Rtype = enum(c_uint) {
    NULL = 0,
    Symbol = 1,
    Pairlist = 2,
    Closure = 3,
    Environment = 4,
    Promise = 5,
    LanguageObject = 6,
    SpecialFunction = 7,
    BuiltinFunction = 8,
    String = 9, // C string
    LogicalVector = 10,

    IntegerVector = 13,
    NumericVector = 14,
    ComplexVector = 15,
    CharacterVector = 16,
    TripleDot = 17,
    Any = 18,
    List = 19,
    Expression = 20,
    Bytecode = 21,
    ExternalPointer = 22,
    WeakReference = 23,
    RawVector = 24,
    Object = 25, // non-vector

    pub fn int(self: Rtype) c_uint {
        return @intFromEnum(self);
    }
};

/// Returns `.True` for any atomic vector type, lists, expressions
pub fn isVector(obj: Robject) Rboolean {
    if (r.Rf_isVector(obj) == 1) {
        return .True;
    }
    return .False;
}

/// Returns `.True` for any atomic vector type
pub fn isVectorAtomic(obj: Robject) Rboolean {
    if (r.Rf_isVectorAtomic(obj) == 1) {
        return .True;
    }
    return .False;
}

/// Returns `.True` for R list or R expression
pub fn isVectorList(obj: Robject) Rboolean {
    if (r.Rf_isVectorList(obj) == 1) {
        return .True;
    }
    return .False;
}

/// Returns `.True` if matrix has a length-2 `dim` attribute
pub fn isMatrix(obj: Robject) Rboolean {
    if (r.Rf_isMatrix(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isPairList(obj: Robject) Rboolean {
    if (r.Rf_isPairList(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isPrimitive(obj: Robject) Rboolean {
    if (r.Rf_isPrimitive(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isTs(obj: Robject) Rboolean {
    if (r.Rf_isTs(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isNumeric(obj: Robject) Rboolean {
    if (r.Rf_isNumeric(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isLogical(obj: Robject) Rboolean {
    if (r.Rf_isLogical(obj) == 1) {
        return .True;
    }
    return .False;
}

/// R matrix is also an R array
pub fn isArray(obj: Robject) Rboolean {
    if (r.Rf_isArray(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isFactor(obj: Robject) Rboolean {
    if (r.Rf_isFactor(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isObject(obj: Robject) Rboolean {
    if (r.Rf_isObject(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isFunction(obj: Robject) Rboolean {
    if (r.Rf_isFunction(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isLanguage(obj: Robject) Rboolean {
    if (r.Rf_isLanguage(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isNewList(obj: Robject) Rboolean {
    if (r.Rf_isNewList(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isList(obj: Robject) Rboolean {
    if (r.Rf_isList(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isOrdered(obj: Robject) Rboolean {
    if (r.Rf_isOrdered(obj) == 1) {
        return .True;
    }
    return .False;
}

pub fn isUnOrdered(obj: Robject) Rboolean {
    if (r.Rf_isUnordered(obj) == 1) {
        return .True;
    }
    return .False;
}
