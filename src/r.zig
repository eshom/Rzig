const std = @import("std");
const rzig = @import("Rzig.zig");
// pub usingnamespace @cImport({
//     @cDefine("R_NO_REMAP", {});
//     @cInclude("R.h");
//     @cInclude("Rinternals.h");
// });

// private types
const Rtype = rzig.Rtype;
const Encoding = rzig.strings.Encoding;
const Robject = rzig.Robject;

// types
pub const Sexprec = opaque {
    const Self = @This();
    /// Protect object from R's GC
    pub fn protect(self: *Self) *Self {
        return rzig.gc.protect_stack.protectSafe(self) catch |e| {
            rzig.errors.stop("Failed to protect object. Caught {!}", .{e});
            unreachable;
        };
    }

    /// Unprotect object from GC. Pops the object at the top of the stack.
    /// Caller needs to make sure the object is at the top of the stack.
    pub fn unprotect(self: *Self) void {
        _ = self;
        rzig.gc.protect_stack.unprotectOnce();
    }

    pub fn isVector(self: *Self) bool {
        const bit: u1 = @intCast(Rf_isVector(self));
        return @bitCast(bit);
    }

    pub fn isTypeOf(self: *Self, t: Rtype) bool {
        return TYPEOF(self) == @as(SexpType, @intCast(t.int()));
    }

    pub fn typeOf(self: *Self) Rtype {
        const t: SexpType = @intCast(TYPEOF(self));
        return @enumFromInt(t);
    }

    pub fn isOrdered(self: *Self) bool {
        return Rf_isOrdered(self) == 1;
    }

    pub fn isUnOrdered(self: *Self) bool {
        return Rf_isUnordered(self) == 1;
    }

    pub fn getListObj(self: *Self, index: usize) Robject {
        if (self.isTypeOf(.List)) {
            return rzig.vec.getListObj(self, index);
        } else {
            rzig.errors.stop("Expected `.List` object, found: {}", .{self.typeOf()});
            unreachable;
        }
    }

    pub fn setListObj(self: *Self, index: usize, what: Robject) void {
        if (self.isTypeOf(.List)) {
            rzig.vec.setListObj(self, index, what);
        } else {
            rzig.errors.stop("Expected `.List` object, found: {}", .{self.typeOf()});
            unreachable;
        }
    }
};

pub const Rcomplex = opaque {};
pub const RcomplexPtr = ?*anyopaque;
pub const Rbool = c_uint;
pub const Rbyte = u8;
pub const Sexp = *Sexprec;
pub const R_allocator_t = opaque {};
pub const SexpType = c_uint;
pub const Anyfn = ?*const fn () callconv(.C) ?*anyopaque;
pub const AnyfnVoid = ?*const fn () callconv(.C) void;
pub const Rboolean = enum(c_int) {
    FALSE,
    TRUE,
};

// constants and external variables/constants
pub const BUFSIZE = 8192;
pub const PIPE_BUF = 4096;
pub const PATH_MAX = 4096;
pub const LINK_MAX = 127;
pub const MAX_CANON = 255;
pub const MAX_INPUT = 255;
pub const NAME_MAX = 255;
pub extern var R_NaN: f64;
pub extern var R_PosInf: f64;
pub extern var R_NegInf: f64;
pub extern var R_NaReal: f64;
pub extern var R_NaInt: c_int;
pub extern var R_GlobalEnv: Sexp;
pub extern var R_EmptyEnv: Sexp;
pub extern var R_BaseEnv: Sexp;
pub extern var R_BaseNamespace: Sexp;
pub extern var R_NamespaceRegistry: Sexp;
pub extern var R_Srcref: Sexp;
pub extern var R_NilValue: Sexp;
pub extern var R_UnboundValue: Sexp;
pub extern var R_MissingArg: Sexp;
pub extern var R_InBCInterpreter: Sexp;
pub extern var R_CurrentExpression: Sexp;
pub extern var R_RestartToken: Sexp;
pub extern var R_AsCharacterSymbol: Sexp;
pub extern var R_AtsignSymbol: Sexp;
pub extern var R_baseSymbol: Sexp;
pub extern var R_BaseSymbol: Sexp;
pub extern var R_BraceSymbol: Sexp;
pub extern var R_Bracket2Symbol: Sexp;
pub extern var R_BracketSymbol: Sexp;
pub extern var R_ClassSymbol: Sexp;
pub extern var R_DeviceSymbol: Sexp;
pub extern var R_DimNamesSymbol: Sexp;
pub extern var R_DimSymbol: Sexp;
pub extern var R_DollarSymbol: Sexp;
pub extern var R_DotsSymbol: Sexp;
pub extern var R_DoubleColonSymbol: Sexp;
pub extern var R_DropSymbol: Sexp;
pub extern var R_EvalSymbol: Sexp;
pub extern var R_FunctionSymbol: Sexp;
pub extern var R_LastvalueSymbol: Sexp;
pub extern var R_LevelsSymbol: Sexp;
pub extern var R_ModeSymbol: Sexp;
pub extern var R_NaRmSymbol: Sexp;
pub extern var R_NameSymbol: Sexp;
pub extern var R_NamesSymbol: Sexp;
pub extern var R_NamespaceEnvSymbol: Sexp;
pub extern var R_PackageSymbol: Sexp;
pub extern var R_PreviousSymbol: Sexp;
pub extern var R_QuoteSymbol: Sexp;
pub extern var R_RowNamesSymbol: Sexp;
pub extern var R_SeedsSymbol: Sexp;
pub extern var R_SortListSymbol: Sexp;
pub extern var R_SourceSymbol: Sexp;
pub extern var R_SpecSymbol: Sexp;
pub extern var R_TripleColonSymbol: Sexp;
pub extern var R_TspSymbol: Sexp;
pub extern var R_dot_defined: Sexp;
pub extern var R_dot_Method: Sexp;
pub extern var R_dot_packageName: Sexp;
pub extern var R_dot_target: Sexp;
pub extern var R_dot_Generic: Sexp;
pub extern var R_NaString: Sexp;
pub extern var R_BlankString: Sexp;
pub extern var R_BlankScalarString: Sexp;

// type/value checking
pub extern fn TYPEOF(x: Sexp) c_int;
pub extern fn R_IsNA(f64) c_int;
pub extern fn R_IsNaN(f64) c_int;
pub extern fn R_finite(f64) c_int;
pub extern fn R_CHAR(x: Sexp) [*c]const u8;
pub extern fn Rf_isNull(s: Sexp) Rbool;
pub extern fn Rf_isSymbol(s: Sexp) Rbool;
pub extern fn Rf_isLogical(s: Sexp) Rbool;
pub extern fn Rf_isReal(s: Sexp) Rbool;
pub extern fn Rf_isComplex(s: Sexp) Rbool;
pub extern fn Rf_isExpression(s: Sexp) Rbool;
pub extern fn Rf_isEnvironment(s: Sexp) Rbool;
pub extern fn Rf_isString(s: Sexp) Rbool;
pub extern fn Rf_isObject(s: Sexp) Rbool;
pub extern fn Rf_any_duplicated(x: Sexp, from_last: Rbool) c_long;
pub extern fn Rf_any_duplicated3(x: Sexp, incomp: Sexp, from_last: Rbool) c_long;
pub extern fn Rf_duplicated(Sexp, Rbool) Sexp;
pub extern fn Rf_isArray(Sexp) Rbool;
pub extern fn Rf_isFactor(Sexp) Rbool;
pub extern fn Rf_isFrame(Sexp) Rbool;
pub extern fn Rf_isFunction(Sexp) Rbool;
pub extern fn Rf_isInteger(Sexp) Rbool;
pub extern fn Rf_isLanguage(Sexp) Rbool;
pub extern fn Rf_isList(Sexp) Rbool;
pub extern fn Rf_isMatrix(Sexp) Rbool;
pub extern fn Rf_isNewList(Sexp) Rbool;
pub extern fn Rf_isNumber(Sexp) Rbool;
pub extern fn Rf_isNumeric(Sexp) Rbool;
pub extern fn Rf_isPairList(Sexp) Rbool;
pub extern fn Rf_isPrimitive(Sexp) Rbool;
pub extern fn Rf_isTs(Sexp) Rbool;
pub extern fn Rf_isUserBinop(Sexp) Rbool;
pub extern fn Rf_isValidString(Sexp) Rbool;
pub extern fn Rf_isValidStringF(Sexp) Rbool;
pub extern fn Rf_isVector(Sexp) Rbool;
pub extern fn Rf_isVectorAtomic(Sexp) Rbool;
pub extern fn Rf_isVectorList(Sexp) Rbool;
pub extern fn Rf_isVectorizable(Sexp) Rbool;
pub extern fn R_isTRUE(Sexp) Rbool;

// to or from R object conversions
pub extern fn Rf_asChar(Sexp) Sexp;
pub extern fn Rf_coerceVector(Sexp, SexpType) Sexp;
pub extern fn Rf_PairToVectorList(x: Sexp) Sexp;
pub extern fn Rf_VectorToPairList(x: Sexp) Sexp;
pub extern fn Rf_asCharacterFactor(x: Sexp) Sexp;
pub extern fn Rf_asLogical(x: Sexp) c_int;
pub extern fn Rf_asInteger(x: Sexp) c_int;
pub extern fn Rf_asReal(x: Sexp) f64;
pub extern fn Rf_asComplex(x: Sexp) Rcomplex;

// copy or allocate objects
pub extern fn Rf_allocVector(SexpType, c_long) Sexp;
pub extern fn Rf_acopy_string([*c]const u8) [*c]u8;
pub extern fn Rf_alloc3DArray(SexpType, c_int, c_int, c_int) Sexp;
pub extern fn Rf_allocArray(SexpType, Sexp) Sexp;
pub extern fn Rf_allocMatrix(SexpType, c_int, c_int) Sexp;
pub extern fn Rf_allocLang(c_int) Sexp;
pub extern fn Rf_allocList(c_int) Sexp;
pub extern fn Rf_allocS4Object() Sexp;
pub extern fn Rf_allocSExp(SexpType) Sexp;
pub extern fn Rf_allocVector3(SexpType, c_long, ?*R_allocator_t) Sexp;
pub extern fn Rf_copyMatrix(Sexp, Sexp, Rbool) void;
pub extern fn Rf_copyListMatrix(Sexp, Sexp, Rbool) void;
pub extern fn Rf_copyMostAttrib(Sexp, Sexp) void;
pub extern fn Rf_copyVector(Sexp, Sexp) void;
pub extern fn Rf_ScalarComplex(Rcomplex) Sexp;
pub extern fn Rf_ScalarInteger(c_int) Sexp;
pub extern fn Rf_ScalarLogical(c_int) Sexp;
pub extern fn Rf_ScalarRaw(Rbyte) Sexp;
pub extern fn Rf_ScalarReal(f64) Sexp;
pub extern fn Rf_ScalarString(Sexp) Sexp;

// R object getters and setters
pub extern fn LOGICAL(x: Sexp) [*c]c_int;
pub extern fn INTEGER(x: Sexp) [*c]c_int;
pub extern fn RAW(x: Sexp) [*c]Rbyte;
pub extern fn REAL(x: Sexp) [*c]f64;
pub extern fn COMPLEX(x: Sexp) RcomplexPtr;
pub extern fn VECTOR_ELT(x: Sexp, i: c_long) Sexp;
pub extern fn SET_VECTOR_ELT(x: Sexp, i: c_long, v: Sexp) Sexp;
pub extern fn STRING_ELT(x: Sexp, i: c_long) Sexp;
pub extern fn SET_STRING_ELT(x: Sexp, i: c_long, v: Sexp) void;
pub extern fn Rf_classgets(Sexp, Sexp) Sexp;
pub extern fn Rf_dimgets(Sexp, Sexp) Sexp;
pub extern fn Rf_dimnamesgets(Sexp, Sexp) Sexp;
pub extern fn Rf_length(Sexp) c_int;
pub extern fn Rf_lengthgets(Sexp, c_int) Sexp;
pub extern fn Rf_xlength(Sexp) c_long;
pub extern fn Rf_xlengthgets(Sexp, c_long) Sexp;

// Print
pub extern fn Rprintf([*c]const u8, ...) void;
pub extern fn REprintf([*c]const u8, ...) void;
pub extern fn WrongArgCount([*c]const u8) void;
pub extern fn R_ShowMessage(s: [*c]const u8) void;

// Errors
pub extern fn Rf_warning([*c]const u8, ...) void;
pub extern fn Rf_error([*c]const u8, ...) void;
pub extern fn Rf_errorcall(Sexp, [*c]const u8, ...) void;
pub extern fn Rf_warningcall(Sexp, [*c]const u8, ...) void;
pub extern fn Rf_warningcall_immediate(Sexp, [*c]const u8, ...) void;

// GC and memory
pub extern fn vmaxget() ?*anyopaque;
pub extern fn vmaxset(?*const anyopaque) void;
pub extern fn R_gc() void;
pub extern fn R_gc_running() c_int;
pub extern fn R_alloc(usize, c_int) [*c]u8;
pub extern fn R_allocLD(nelem: usize) [*c]c_longdouble;
pub extern fn S_alloc(c_long, c_int) [*c]u8;
pub extern fn S_realloc([*c]u8, c_long, c_long, c_int) [*c]u8;
pub extern fn R_malloc_gc(usize) ?*anyopaque;
pub extern fn R_calloc_gc(usize, usize) ?*anyopaque;
pub extern fn R_realloc_gc(?*anyopaque, usize) ?*anyopaque;
pub extern fn R_chk_calloc(usize, usize) ?*anyopaque;
pub extern fn R_chk_realloc(?*anyopaque, usize) ?*anyopaque;
pub extern fn R_chk_free(?*anyopaque) void;
pub extern fn Rf_protect(Sexp) Sexp;
pub extern fn Rf_unprotect(c_int) void;
pub extern fn R_ProtectWithIndex(Sexp, [*c]c_int) void;
pub extern fn R_Reprotect(Sexp, c_int) void;

// RNG
pub extern fn GetRNGstate() void;
pub extern fn PutRNGstate() void;
pub extern fn unif_rand() f64;
pub extern fn R_unif_index(f64) f64;
pub extern fn norm_rand() f64;
pub extern fn exp_rand() f64;

// Sort
pub extern fn R_isort([*c]c_int, c_int) void;
pub extern fn R_rsort([*c]f64, c_int) void;
pub extern fn R_csort(?*Rcomplex, c_int) void;
pub extern fn rsort_with_index([*c]f64, [*c]c_int, c_int) void;
pub extern fn Rf_revsort([*c]f64, [*c]c_int, c_int) void;
pub extern fn Rf_iPsort([*c]c_int, c_int, c_int) void;
pub extern fn Rf_rPsort([*c]f64, c_int, c_int) void;
pub extern fn Rf_cPsort(?*Rcomplex, c_int, c_int) void;
pub extern fn R_qsort(v: [*c]f64, i: usize, j: usize) void;
pub extern fn R_qsort_I(v: [*c]f64, II: [*c]c_int, i: c_int, j: c_int) void;
pub extern fn R_qsort_int(iv: [*c]c_int, i: usize, j: usize) void;
pub extern fn R_qsort_int_I(iv: [*c]c_int, II: [*c]c_int, i: c_int, j: c_int) void;
pub extern fn Rf_isOrdered(Sexp) Rbool;
pub extern fn Rf_isUnordered(Sexp) Rbool;
pub extern fn Rf_isUnsorted(Sexp, Rbool) Rbool;

// Filesystem
pub extern fn R_ExpandFileName([*c]const u8) [*c]const u8;

// Strings
pub extern fn Rf_mkCharLen([*c]const u8, c_int) Sexp;
pub extern fn Rf_mkCharLenCE([*c]const u8, c_int, Encoding) Sexp;
pub extern fn Rf_getCharCE(Sexp) Encoding;
pub extern fn Rf_StringFalse([*c]const u8) Rbool;
pub extern fn Rf_StringTrue([*c]const u8) Rbool;
pub extern fn Rf_isBlankString([*c]const u8) Rbool;

// Runtime checks
pub extern fn R_CheckUserInterrupt() void;
pub extern fn R_CheckStack() void;
pub extern fn R_CheckStack2(usize) void;

// Embedded R
pub extern fn R_FlushConsole() void;
pub extern fn R_ProcessEvents() void;
pub extern fn Rf_defineVar(Sexp, Sexp, Sexp) void;

// External Pointers
pub extern fn R_MakeExternalPtr(p: ?*anyopaque, tag: Sexp, prot: Sexp) Sexp;
pub extern fn R_ExternalPtrAddr(s: Sexp) ?*anyopaque;
pub extern fn R_MakeExternalPtrFn(p: Anyfn, tag: Sexp, prot: Sexp) Sexp;
pub extern fn R_ExternalPtrAddrFn(s: Sexp) Anyfn;

// Eval
pub extern fn Rf_eval(Sexp, Sexp) Sexp;
pub extern fn R_tryEval(Sexp, Sexp, [*c]c_int) ?Sexp;
pub extern fn R_tryEvalSilent(Sexp, Sexp, [*c]c_int) ?Sexp;
pub extern fn R_ToplevelExec(fun: ?*const fn (?*anyopaque) callconv(.C) void, data: ?*anyopaque) Rboolean;
