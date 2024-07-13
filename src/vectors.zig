const std = @import("std");
const math = std.math;
const mem = std.mem;

const r = @import("r.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");

const r_null = constants.r_null;
const Allocator = mem.Allocator;
const Rtype = types.Rtype;
const Rboolean = types.Rboolean;

pub const Robject = types.Robject;

pub const CoercionError = error{
    UnsupportedType,
    WrongType,
    NotAVector,
};

pub const SizeError = error{
    CannotEnlarge,
    IntegerTooSmall,
};

/// Get length of R object
pub fn length(obj: Robject) usize {
    const len = r.Rf_xlength(obj);
    return @intCast(len);
}

/// Get length of R object, 32 bit version
pub fn length32(obj: Robject) i32 {
    const len = r.Rf_length(obj);
    return @intCast(len);
}

/// Resize R vector to shorter length.
/// There is no gurantee allocated object is re-used.
/// For saftey protect result object.
pub fn resizeVec(obj: Robject, new_len: usize) Robject {
    const len = length(obj);

    if (len > new_len) {
        errors.stop("Cannot enlarge vector. Only shrinking is supported.");
        unreachable;
    }

    return r.Rf_xlengthgets(obj, @intCast(new_len));
}

/// Resize R vector to shorter length. 32-bit version
/// See: `resizeVec()`
pub fn resizeVec32(obj: Robject, new_len: usize) Robject {
    const len = length(obj);

    if (len > new_len) {
        errors.stop("Cannot enlarge vector. Only shrinking is supported.");
        unreachable;
    }

    if (len > math.maxInt(c_int)) {
        errors.stop("Trying to resize 64-bit vector with 32-bit version. Use `resizeVec()` instead.");
        unreachable;
    }

    return r.Rf_lengthgets(obj, @intCast(new_len));
}

/// Coerces `Robject` to a specific `Rtype`.
/// Returns `Robject` which points to requested type.
/// If coercsion is not supported, returns `UnsupportedType`.
///
/// Return value must be protected from GC by caller.
pub fn asVector(to: Rtype, from: Robject) Robject {
    const out: Robject = switch (to) {
        .LogicalVector,
        .IntegerVector,
        .NumericVector,
        .CharacterVector,
        .ComplexVector,
        .List,
        .RawVector,
        => r.Rf_coerceVector(from, @intCast(@intFromEnum(to))),
        else => @compileError("Coercsion to vector not supported for specified tag"),
    };

    return out;
}

/// Get R object from List.
///
/// Return value does not need to be protected from GC.
pub fn getListObj(list: Robject, index: usize) Robject {
    return r.VECTOR_ELT(list, @intCast(index));
}

pub fn setListObj(list: Robject, index: usize, what: Robject) void {
    _ = r.SET_VECTOR_ELT(list, @intCast(index), what);
}

/// Get R object from List and return slice to its underlying primitive array
///
/// bool type is not supported, as you can't cast []c_int to []bool.
/// For bools use `getListObj()` and unwrap it with either `toBoolSlice()` or `toU32SliceFromLogical()`.
pub fn getListElem(T: type, list: Robject, index: usize) []T {
    return toSlice(T, getListObj(list, index));
}

fn logicalToBool(v: c_int) bool {
    const bit: u1 = @intCast(v);
    return @bitCast(bit);
}

/// Coerces a vector to a primitive type.
///
/// `T` can be one of:
/// bool, c_int, i32, f64
/// Otherwise error `UnsupportedType` is returned
///
/// `from` must be an R vector otherwise `NotAVector` error is returned.
/// Vectors with length greater than 1 return only their first element.
pub fn asPrimitive(T: type, from: Robject) T {
    const is_vec: Rboolean = types.isVector(from);

    if (is_vec == .False) {
        errors.stop("Object to coerce must be a vector", .{});
        unreachable;
    }

    const out: T = switch (T) {
        c_int => r.Rf_asInteger(from),
        i32 => @intCast(r.Rf_asInteger(from)),
        bool => logicalToBool(r.Rf_asLogical(from)),
        f64 => r.Rf_asReal(from),
        else => @compileError("Coercsion is not supported for specified type"),
    };

    return out;
}

/// Convert R object to underlying primitive type slice
/// Supported types: c_int, i32, f64
///
/// For bools, use either `toBoolSlice()` or `toU32SliceFromLogical()`
pub fn toSlice(T: type, from: Robject) []T {
    const is_vec = types.isVector(from);

    if (is_vec == .False) {
        errors.stop("Object to coerce must be a vector", .{});
        unreachable;
    }

    const len = length(from);

    const out: []T = switch (T) {
        c_int => r.INTEGER(from)[0..len],
        i32 => @ptrCast(r.INTEGER(from)[0..len]),
        f64 => r.REAL(from)[0..len],
        bool => @compileError("Cannot directly cast []c_int to []bool. Use either `toBoolSlice()` or `toU32SliceFromLogical()`"),
        else => @compileError("Coercsion is not supported for specified type"),
    };

    return out;
}

/// Convert R logical vector to slice of bools.
///
/// Depending on the allocator used, caller or R's GC must free memory.
pub fn toBoolSlice(allocator: Allocator, obj: Robject) []bool {
    if (types.isLogical(obj) == .False) {
        errors.stop("Object passed must be a logical vector.", .{});
        unreachable;
    }

    const len = length(obj);
    const out = allocator.alloc(bool, len) catch {
        errors.stop("Failed allocation. Out of memory.", .{});
        unreachable;
    };
    const src: []c_int = r.LOGICAL(obj)[0..len];

    for (out, src) |*elem_dest, elem_src| {
        elem_dest.* = logicalToBool(elem_src);
    }

    return out;
}

/// Convert R logical vector to underlying primitive type slice.
pub fn toU32SliceFromLogical(obj: Robject) []u32 {
    if (types.isLogical(obj) == .False) {
        errors.stop("Object passed must be a logical vector.", .{});
        unreachable;
    }

    const len = length(obj);
    return @ptrCast(r.LOGICAL(obj)[0..len]);
}

/// Coerces primitive type to R atomic vector.
///
/// Returns R NULL if coercsion is not supported.
pub fn asScalarVector(from: anytype) Robject {
    const T = @TypeOf(from);

    const out = switch (T) {
        f64 => r.Rf_ScalarReal(from),
        bool => r.Rf_ScalarLogical(@intCast(@intFromBool(from))),
        c_int, i32, comptime_int => r.Rf_ScalarInteger(@intCast(from)),
        else => return r_null,
    };

    return out;
}

/// Allocate new vector.
/// Memory is managed by R's GC.
/// Caller must protect new vector from GC.
pub fn allocVector(t: Rtype, len: usize) Robject {
    return r.Rf_allocVector(t.int(), @intCast(len));
}
