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

export fn testWarning2() Robject {
    const msg = "." ** 1000;
    const msg2 = "A" ** 1000;
    rzig.errors.warning("{s}{s}\n", .{ msg, msg2 });
    return r_null.*;
}

export fn testStopCall(callback: Robject) Robject {
    const msg = "Test error message";
    const num = 1234;

    rzig.errors.stopCall(callback, "{s} {d}\n", .{ msg, num });

    unreachable;
}

export fn testWarningCall(callback: Robject) Robject {
    const msg = "Test error message";
    const num = 4321;

    rzig.errors.warningCall(callback, "{s} {d}\n", .{ msg, num });
    return r_null.*;
}

export fn testWarningCallImmediate(callback: Robject) Robject {
    const msg = "Test error message";
    const num = 654321;

    rzig.errors.warningCallImmediate(callback, "{s} {d}\n", .{ msg, num });
    return r_null.*;
}

export fn testShowMessage() Robject {
    const msg =
        \\Important message:
        \\This is a test.
        \\
    ;

    rzig.io.showMessage("{s}", .{msg});
    return r_null.*;
}

export fn testPrintValue(expr: Robject, envir: Robject) Robject {
    return rzig.eval.eval(expr, envir);
}

export fn testAllocateSomeVectors() Robject {
    var prot = rzig.gc.ProtectStack.init();
    defer prot.deinit();

    const list = prot.protect(rzig.vec.allocVector(.List, 3)) catch unreachable;
    const numeric = prot.protect(rzig.vec.allocVector(.NumericVector, 3)) catch unreachable;
    const ints = prot.protect(rzig.vec.allocVector(.IntegerVector, 3)) catch unreachable;
    const logicals = prot.protect(rzig.vec.allocVector(.LogicalVector, 3)) catch unreachable;

    for (rzig.vec.toSlice(f64, numeric) catch unreachable) |*val| {
        val.* = 0.5;
    }

    for (rzig.vec.toSlice(i32, ints) catch unreachable) |*val| {
        val.* = 0;
    }

    for (rzig.vec.toU32SliceFromLogical(logicals) catch unreachable) |*val| {
        val.* = 0;
    }

    rzig.vec.setListObj(list, 0, numeric);
    rzig.vec.setListObj(list, 1, ints);
    rzig.vec.setListObj(list, 2, logicals);

    return list;
}
