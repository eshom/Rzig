const std = @import("std");
const mem = std.mem;
const math = std.math;
const testing = std.testing;

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
        errors.stop("Cannot get encoding from non-string object", .{});
    }
    return r.Rf_getCharCE(obj);
}

test "getEncoding" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\smile <- "\U0001f604"
        \\Encoding(smile) <- "bytes"
        \\.Call('testGetEncoding', smile)
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
        \\[1] TRUE
        \\
    ;

    testing.expectEqualStrings(expected, result.stdout) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };

    try testing.expectEqualStrings("", result.stderr);
}

/// Make String object. Uses current encoding.
/// R will copy the string if it doesn't have a matching string cached and will managed its memory.
pub fn makeString(str: []const u8) Robject {
    if (str.len > math.maxInt(i32)) {
        errors.stop("makeString(): R does not support strings longer than 2^31 - 1", .{});
    }

    if (str.len > math.maxInt(c_int)) {
        errors.stop("Length value of {} is larger than a 32-bit signed integer can represent", .{str.len});
    }

    return r.Rf_mkCharLen(str.ptr, @intCast(str.len));
}

/// Make String object in specified encoding.
/// R will copy the string if it doesn't have a matching string cached and will managed its memory.
pub fn makeStringEncoding(str: []const u8, encoding: Encoding) Robject {
    if (str.len > math.maxInt(i32)) {
        errors.stop("makeStringEncoding(): R does not support strings longer than 2^31 - 1", .{});
    }

    return r.Rf_mkCharLenCE(str.ptr, @intCast(str.len), encoding);
}

pub fn getString(char_vec: Robject, index: usize) Robject {
    if (!char_vec.isTypeOf(.CharacterVector)) {
        errors.stop("Cannot get string object from non-character vector", .{});
    }

    const len = char_vec.length();

    if (index >= len) {
        errors.stop("Character vector index out of bounds. Index: {d}, length: {d}\n", .{ index, len });
    }

    return r.STRING_ELT(char_vec, @intCast(index));
}

pub fn setString(char_vec: Robject, index: usize, string_obj: Robject) void {
    if (!char_vec.isTypeOf(.CharacterVector)) {
        errors.stop("Cannot get string object from non-character vector", .{});
    }

    if (!string_obj.isTypeOf(.String)) {
        errors.stop("Cannot assign non-string to character vector", .{});
    }

    const len = char_vec.length();

    if (index >= len) {
        errors.stop("Character vector index out of bounds. Index: {d}, length: {d}\n", .{ index, len });
    }

    if (index > math.maxInt(c_long)) {
        errors.stop("Index value of {} is larger than the maximum `c_long` can represent: {}", .{ index, math.maxInt(c_long) });
    }

    r.SET_STRING_ELT(char_vec, @intCast(index), string_obj);
}
