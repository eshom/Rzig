const std = @import("std");
const rzig = @import("Rzig");

fn errorString(err: anyerror) [*:0]const u8 {
    return @errorName(err);
}

export fn hello() rzig.RObject {
    const writer = rzig.print.RStdoutWriter().writer();
    writer.print("Hello, World!\n", .{}) catch unreachable;
    return rzig.asScalarVector(true) catch |err| {
        rzig.errors.stop("%s. In `hello()`: Problem while calling `asScalarVector()`\n", errorString(err));
        unreachable;
    };
}

export fn allocPrintTest() rzig.RObject {
    const allocator = rzig.heap.r_allocator;
    const writer = rzig.print.RStdoutWriter().writer();

    const buf = allocator.alloc(u8, 10) catch |err| {
        rzig.errors.stop("%s. In `allocPrintTest()`: Problem allocating memory\n", errorString(err));
        unreachable;
    };
    defer allocator.free(buf);

    for (buf) |*c| {
        c.* = 'X';
    }

    writer.print("{s}\n", .{buf.ptr}) catch unreachable;

    return rzig.asScalarVector(true) catch |err| {
        rzig.errors.stop("%s. In `allocPrintTest()`: Problem while calling `asScalarVector()`\n", errorString(err));
        unreachable;
    };
}

export fn allocResizePrintTest() rzig.RObject {
    const allocator = rzig.heap.r_allocator;
    const writer = rzig.print.RStdoutWriter().writer();

    const buf = allocator.alloc(u40, 10) catch |err| {
        rzig.errors.stop("%s. In `allocResizePrintTest()`: Problem allocating memory\n", errorString(err));
        unreachable;
    };
    defer allocator.free(buf);

    const ptr_good = allocator.resize(buf, 10);
    if (!ptr_good) {
        rzig.errors.stop("%s. In `allocResizePrintTest()`: problem resizing memory, unexpected invalid pointer address\n");
        unreachable;
    }

    const resize_fail = allocator.resize(buf, 15);
    if (!resize_fail) {
        writer.print("Expecting this message when resizing\n", .{}) catch unreachable;
    }

    for (buf, 0..) |*cell, n| {
        cell.* = @truncate(n);
    }

    inline for (0..10) |n| {
        writer.print("{d} ", .{n}) catch unreachable;
    }
    writer.print("\n", .{}) catch unreachable;

    return rzig.asScalarVector(true) catch |err| {
        rzig.errors.stop("%s. In `allocResizePrintTest()`: Problem while calling `asScalarVector()`\n", errorString(err));
        unreachable;
    };
}
