const std = @import("std");
const rzig = @import("Rzig");

const RObject = rzig.RObject;
const r_null = rzig.r_null;

fn errorString(err: anyerror) [*:0]const u8 {
    return @errorName(err);
}

export fn testHello() RObject {
    const writer = rzig.io.RStdoutWriter().writer();
    writer.print("Hello, World!\n", .{}) catch unreachable;
    return r_null.*;
}

export fn testHelloCFormat() RObject {
    const writer = rzig.io.RStdoutWriter().writer();
    writer.print("%d%d%sHello, World!%d%d%s\n", .{}) catch unreachable;
    return r_null.*;
}

export fn testHelloStderr() RObject {
    const writer = rzig.io.RStderrWriter().writer();
    writer.print("Hello, Error!\n", .{}) catch unreachable;
    return r_null.*;
}

export fn testAllocPrint() RObject {
    const allocator = rzig.heap.r_allocator;
    const writer = rzig.io.RStdoutWriter().writer();

    const buf = allocator.alloc(u8, 10) catch |err| {
        rzig.errors.stop("%s. In `testAllocPrint()`: Problem allocating memory\n", errorString(err));
        unreachable;
    };
    defer allocator.free(buf);

    for (buf) |*c| {
        c.* = 'X';
    }

    writer.print("{s}\n", .{buf}) catch unreachable;

    return r_null.*;
}

export fn testAllocResizePrint() RObject {
    const allocator = rzig.heap.r_allocator;
    const writer = rzig.io.RStdoutWriter().writer();

    const Integer = u32;

    const buf = allocator.alloc(Integer, 20) catch |err| {
        rzig.errors.stop("%s. In `testAllocResizePrint()`: Problem allocating memory\n", errorString(err));
        unreachable;
    };
    defer allocator.free(buf);

    const ptr_good = allocator.resize(buf, 20);
    if (!ptr_good) {
        rzig.errors.stop("%s. In `testAllocResizePrint()`: problem resizing memory, unexpected invalid pointer address\n");
        unreachable;
    }

    const resize_fail = allocator.resize(buf, 25);
    if (!resize_fail) {
        writer.print("Expecting this message when resizing\n", .{}) catch unreachable;
    }

    var n: Integer = 0;
    for (buf) |*cell| {
        cell.* = n;
        n += 1;
    }

    writer.print("{d}\n", .{buf}) catch unreachable;

    return r_null.*;
}

// export fn testAsVector(
//     logical: RObject,
//     integer: RObject,
//     numeric: RObject,
//     character: RObject,
//     // complex: RObject,
//     list: RObject,
// ) RObject {
//     const raw_integer = rzig.asVector(.RawVector, logical) catch unreachable;
//     const raw_logical = rzig.asVector(.RawVector, integer) catch unreachable;
//     const raw_numeric = rzig.asVector(.RawVector, numeric) catch unreachable;
//     const raw_character = rzig.asVector(.RawVector, character) catch unreachable;
//     const raw_list = rzig.asVector(.RawVector, list) catch unreachable;
//
//     return rzig.rzig.internal_R_api.R_NilValue;
// }
