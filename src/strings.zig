const std = @import("std");
const mem = std.mem;
const math = std.math;

const r = @import("r.zig");
const rzig = @import("Rzig.zig");
const errors = rzig.errors;
const vec = rzig.vec;

const Robject = rzig.Robject;

pub const Encoding = enum(c_uint) {
    native = 0,
    utf8 = 1,
    latin1 = 2,
    bytes = 3,
    symbol = 5,
    any = 99,

    pub fn int(self: Encoding) c_uint {
        return @intFromEnum(self);
    }
};

/// Get encoding from internal C string object
pub fn getEncoding(obj: Robject) Encoding {
    if (!obj.isTypeOf(.String)) {
        errors.stop("Cannot get encoding from non-string object");
    }
    return @enumFromInt(r.Rf_getCharCE(obj));
}

/// Make String object. Uses current encoding.
/// R will copy the string if it doesn't have a matching string cached and will managed its memory.
pub fn makeString(str: []const u8) Robject {
    if (!(str.len > math.maxInt(i32) - 1)) {
        errors.stop("R does not support strings longer than 2^31 - 1", .{});
        unreachable;
    }

    r.Rf_mkCharLen(str.ptr, str.len);
}

/// Make String object in specified encoding.
/// R will copy the string if it doesn't have a matching string cached and will managed its memory.
pub fn makeStringEncoding(str: []const u8, encoding: Encoding) Robject {
    if (!(str.len > math.maxInt(i32) - 1)) {
        errors.stop("R does not support strings longer than 2^31 - 1", .{});
        unreachable;
    }

    r.Rf_mkCharLenCE(str.ptr, str.len, encoding.int());
}

pub fn getString(char_vec: Robject, index: usize) Robject {
    if (!char_vec.isTypeOf(.CharacterVector)) {
        errors.stop("Cannot get string object from non-character vector", .{});
    }

    const len = vec.length(char_vec);

    if (index >= len) {
        errors.stop("Character vector index out of bounds. Index: {d}, length: {d}\n", .{ index, len });
    }

    return r.STRING_ELT(char_vec, @intCast(index));
}

pub fn setString(char_vec: Robject, index: usize, string_obj: Robject) Robject {
    if (!char_vec.isTypeOf(.CharacterVector)) {
        errors.stop("Cannot get string object from non-character vector");
    }

    if (!string_obj.isTypeOf(.String)) {
        errors.stop("Cannot assign non-string to character vector");
    }

    const len = vec.length(char_vec);

    if (index >= len) {
        errors.stop("Character vector index out of bounds. Index: {d}, length: {d}\n", .{ index, len });
    }

    return r.SET_STRING_ELT(char_vec, index, string_obj);
}
