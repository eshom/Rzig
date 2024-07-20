//! References:
//!     https://cran.r-project.org/doc/manuals/R-ints.html
//!     https://cran.r-project.org/doc/manuals/R-exts.html

const r = @import("r.zig");

const std = @import("std");
const testing = std.testing;

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

// ---------
// Types
// ---------

/// General purpose R object (SEXP).
/// Must use R API functions to access values and coerce to other types.
pub const Robject = r.Sexp;

pub const Rcomplex = r.Rcomplex;

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

test "R type checks" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\obj <- list()
        \\obj[[1]] <- quote(x)
        \\obj[[2]] <- pairlist(1)
        \\obj[[3]] <- function(x) 1 + 1
        \\obj[[4]] <- new.env()
        \\obj[[5]] <- call("any")
        \\obj[[6]] <- `[`
        \\obj[[7]] <- `+`
        \\obj[[8]] <- "test"
        \\.Call('testIsObjects', obj)
    ;

    const result = try std.process.Child.run(.{
        .allocator = testing.allocator,
        .argv = &.{
            "Rscript",
            "--vanilla",
            "-e",
            code,
        },
    });

    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    const expected =
        \\[[1]]
        \\[1] TRUE
        \\
        \\[[2]]
        \\[1] TRUE
        \\
        \\[[3]]
        \\[1] TRUE
        \\
        \\[[4]]
        \\[1] TRUE
        \\
        \\[[5]]
        \\[1] TRUE
        \\
        \\[[6]]
        \\[1] TRUE
        \\
        \\[[7]]
        \\[1] TRUE
        \\
        \\[[8]]
        \\[1] TRUE
        \\
        \\[[9]]
        \\[1] TRUE
        \\
        \\[[10]]
        \\[1] TRUE
        \\
        \\
    ;

    testing.expectEqualStrings(expected, result.stdout) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };

    try testing.expectEqualStrings("", result.stderr);
}

// ---------
// Constants
// ---------
pub const r_null: *Robject = &r.R_NilValue;
