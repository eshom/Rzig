//! R types and coercison functions

const r = @import("r.zig");

/// General purpose R object (SEXP).
/// Must use R API functions to access values and coerce to other types.
pub const RObject = ?*r.struct_SEXPREC;

pub const Rboolean = enum(c_uint) {
    False = 0,
    True = 1,
};

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
pub const RType = enum(c_int) {
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
};

pub const CoercionError = error{
    UnsupportedType,
    WrongType,
    NotAVector,
};

/// Coerces `RObject` to a specific `RType`.
/// Returns `RObject` which points to requested type.
/// If coercsion is not supported, returns `UnsupportedType`.
///
/// Return value must be protected from GC by caller.
pub fn asVector(to: RType, from: RObject) CoercionError!RObject {
    const out: RObject = switch (to) {
        .LogicalVector,
        .IntegerVector,
        .NumericVector,
        .CharacterVector,
        .ComplexVector,
        .List,
        .RawVector,
        => r.Rf_coerceVector(from, to),
        else => return CoercionError.UnsupportedType,
    };

    return out;
}

/// Coerces a vector to a basic type.
///
/// `T` can be one of:
/// bool, c_int, f64,
/// Otherwise error `UnsupportedType` is returned
///
/// `from` must be a vector otherwise `NotAVector` error is returned.
/// Vectors with length greater than 1 return only their first element.
pub fn asPrimitive(T: type, from: RObject) CoercionError!T {
    const is_vec: Rboolean = @enumFromInt(r.Rf_isVector(from));
    if (is_vec == .False) {
        return CoercionError.NotAVector;
    }

    const out: T = switch (T) {
        c_int => r.Rf_asInteger(from),
        bool => @bitCast(@as(u1, @truncate(@as(c_uint, @intCast(r.Rf_asLogical(from)))))),
        f64 => r.Rf_asReal(from),
        else => CoercionError.UnsupportedType,
    };

    return out;
}

pub fn asScalarVector(from: anytype) CoercionError!RObject {
    const T = @TypeOf(from);

    const out = switch (T) {
        f64 => r.Rf_ScalarReal(from),
        bool => r.Rf_ScalarLogical(@intCast(@intFromBool(from))),
        c_int, i32 => out: {
            const from_int: c_int = from;
            break :out r.Rf_ScalarInteger(from_int);
        },
        else => return CoercionError.UnsupportedType,
    };

    return out;
}
