const std = @import("std");
const rzig = @import("Rzig");

const Robject = rzig.Robject;
const r_null = rzig.r_null;

fn errorString(err: anyerror) [*:0]const u8 {
    return @errorName(err);
}

export fn testHello() Robject {
    const writer = rzig.io.RStdoutWriter().writer();
    writer.print("Hello, World!\n", .{}) catch unreachable;
    return r_null.*;
}

export fn testHelloCFormat() Robject {
    const writer = rzig.io.RStdoutWriter().writer();
    writer.print("%d%d%sHello, World!%d%d%s\n", .{}) catch unreachable;
    return r_null.*;
}

export fn testHelloStderr() Robject {
    const writer = rzig.io.RStderrWriter().writer();
    writer.print("Hello, Error!\n", .{}) catch unreachable;
    return r_null.*;
}

export fn testAllocPrint() Robject {
    const allocator = rzig.heap.r_allocator;
    const writer = rzig.io.RStdoutWriter().writer();

    const buf = allocator.alloc(u8, 10) catch |err| {
        rzig.errors.stop("{!}. In `testAllocPrint()`: Problem allocating memory\n", .{err});
        unreachable;
    };
    defer allocator.free(buf);

    for (buf) |*c| {
        c.* = 'X';
    }

    writer.print("{s}\n", .{buf}) catch unreachable;

    return r_null.*;
}

export fn testAllocResizePrint() Robject {
    const allocator = rzig.heap.r_allocator;
    const writer = rzig.io.RStdoutWriter().writer();

    const Integer = u32;

    const buf = allocator.alloc(Integer, 20) catch |err| {
        rzig.errors.stop("{!}. In `testAllocResizePrint()`: Problem allocating memory\n", .{err});
        unreachable;
    };
    defer allocator.free(buf);

    const ptr_good = allocator.resize(buf, 20);
    if (!ptr_good) {
        rzig.errors.stop("In `testAllocResizePrint()`: problem resizing memory, unexpected invalid pointer address\n", .{});
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

export fn testStop() Robject {
    rzig.errors.stop("Test error message\n", .{});

    unreachable;
}

export fn testStop2() Robject {
    rzig.errors.stop("." ** 1000 ++ "\n", .{});

    unreachable;
}

export fn testWarning() Robject {
    rzig.errors.warning("Test warning message {d}\n", .{1234});
    return r_null.*;
}

// export fn testAsVector(
//     logical: Robject,
//     integer: Robject,
//     numeric: Robject,
//     character: Robject,
//     // complex: Robject,
//     list: Robject,
// ) Robject {
//     const raw_integer = rzig.asVector(.RawVector, logical) catch unreachable;
//     const raw_logical = rzig.asVector(.RawVector, integer) catch unreachable;
//     const raw_numeric = rzig.asVector(.RawVector, numeric) catch unreachable;
//     const raw_character = rzig.asVector(.RawVector, character) catch unreachable;
//     const raw_list = rzig.asVector(.RawVector, list) catch unreachable;
//
//     return rzig.rzig.internal_R_api.R_NilValue;
// }
