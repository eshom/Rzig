const std = @import("std");
const math = std.math;
const mem = std.mem;
const fmt = std.fmt;
const testing = std.testing;

const r = @import("r.zig");
const rzig = @import("Rzig.zig");

const errors = rzig.errors;

const Allocator = mem.Allocator;
const Rtype = rzig.Rtype;
const Robject = rzig.Robject;
const Rcomplex = rzig.Rcomplex;

const r_null = rzig.r_null;

pub const CoercionError = error{
    UnsupportedType,
    WrongType,
    NotAVector,
};

pub const SizeError = error{
    CannotEnlarge,
    IntegerTooSmall,
};

//TODO: Move length functions to Robject as methods
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

//TODO: Move asVector-like functions to Robject as methods
/// Coerces `Robject` to a specific `Rtype`.
/// Returns `Robject` which points to requested type.
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
    return toSlice(T, list.?.getListObj(index));
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
    if (!from.?.isVector()) {
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
    if (!from.?.isVector()) {
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
    if (!obj.?.isTypeOf(.LogicalVector)) {
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
    if (!obj.?.isTypeOf(.LogicalVector)) {
        errors.stop("Object passed must be a logical vector.", .{});
        unreachable;
    }

    const len = length(obj);
    return @ptrCast(r.LOGICAL(obj)[0..len]);
}

/// Coerces primitive type to R atomic vector.
pub fn asScalarVector(from: anytype) Robject {
    const T = @TypeOf(from);

    const out = switch (T) {
        f64 => r.Rf_ScalarReal(from),
        c_int => r.Rf_ScalarInteger(@intCast(from)),
        bool => r.Rf_ScalarLogical(@intCast(@intFromBool(from))),
        else => blk: {
            switch (@typeInfo(T)) {
                .Float, .ComptimeFloat => {
                    break :blk r.Rf_ScalarReal(@floatCast(from));
                },
                .Int, .ComptimeInt => {
                    if (from > math.maxInt(c_int)) {
                        errors.stop("Number is larger than 32-bit integer can represent. Max: {d}, found: {d}", .{ math.maxInt(c_int), from });
                        unreachable;
                    }

                    if (from < math.minInt(c_int)) {
                        errors.stop("Number is smaller than 32-bit integer can represent. Min: {d}, found: {d}", .{ math.minInt(c_int), from });
                        unreachable;
                    }

                    break :blk r.Rf_ScalarInteger(@intCast(from));
                },
                else => @compileError("Attempting to coerce unsupported type"),
            }
        },
    };

    return out;
}

test "asScalarVector" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testAsScalarVector')
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
        \\[1] 1.32456e+32
        \\
        \\[[2]]
        \\[1] -9.87123e-32
        \\
        \\[[3]]
        \\[1] Inf
        \\
        \\[[4]]
        \\[1] -Inf
        \\
        \\[[5]]
        \\[1] NaN
        \\
        \\[[6]]
        \\[1] -9.1e+300
        \\
        \\[[7]]
        \\[1] 1.2e-300
        \\
        \\[[8]]
        \\[1] Inf
        \\
        \\[[9]]
        \\[1] -Inf
        \\
        \\[[10]]
        \\[1] NaN
        \\
        \\[[11]]
        \\[1] -9.1e+307
        \\
        \\[[12]]
        \\[1] 1.2e-307
        \\
        \\[[13]]
        \\[1] Inf
        \\
        \\[[14]]
        \\[1] -Inf
        \\
        \\[[15]]
        \\[1] 5
        \\
        \\[[16]]
        \\[1] -5
        \\
        \\[[17]]
        \\[1] 4
        \\
        \\[[18]]
        \\[1] -4
        \\
        \\[[19]]
        \\[1] 0
        \\
        \\[[20]]
        \\[1] 2000000000
        \\
        \\[[21]]
        \\[1] -2000000000
        \\
        \\[[22]]
        \\[1] TRUE
        \\
        \\[[23]]
        \\[1] FALSE
        \\
        \\
    ;

    testing.expectEqualStrings(expected, result.stdout) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };

    try testing.expectEqualStrings("", result.stderr);
}

test "asScalarVectorError" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testAsScalarVectorError')
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

    const expected = "Error: Number is larger than 32-bit integer can represent. Max: " ++
        fmt.comptimePrint("{d}", .{math.maxInt(c_int)}) ++
        ", found: 2000000000000\n" ++
        "Execution halted\n";

    try testing.expectEqualStrings("", result.stdout);
    try testing.expectEqualStrings(expected, result.stderr);
}

/// Allocate new vector.
/// Memory is managed by R's GC.
/// Caller must protect new vector from GC.
pub fn allocVector(t: Rtype, len: usize) Robject {
    return r.Rf_allocVector(t.int(), @intCast(len));
}
