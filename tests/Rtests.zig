const std = @import("std");
const rzig = @import("Rzig");

const Robject = rzig.Robject;
const Rcomplex = rzig.Rcomplex;

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
    defer rzig.gc.protect_stack.unprotectAll();

    const list = rzig.vec.allocVector(.List, 3).?.protect();
    const numeric = rzig.vec.allocVector(.NumericVector, 3).?.protect();
    const ints = rzig.vec.allocVector(.IntegerVector, 3).?.protect();
    const logicals = rzig.vec.allocVector(.LogicalVector, 3).?.protect();

    for (rzig.vec.toSlice(f64, numeric)) |*val| {
        val.* = 0.5;
    }

    for (rzig.vec.toSlice(i32, ints)) |*val| {
        val.* = 0;
    }

    for (rzig.vec.toU32SliceFromLogical(logicals)) |*val| {
        val.* = 0;
    }

    rzig.vec.setListObj(list, 0, numeric);
    rzig.vec.setListObj(list, 1, ints);
    rzig.vec.setListObj(list, 2, logicals);

    return list;
}

export fn testIsObjects(list: Robject) Robject {
    //TODO: Add type checks for the following more tricky types:
    // .Promise
    // .Tripledot
    // .Any, although it might not be supported as part of the official API.
    // .Bytecode
    defer rzig.gc.protect_stack.unprotectAll();
    const results = rzig.vec.allocVector(.List, 17).?.protect();

    const char_vec = rzig.vec.getListObj(list, 7);
    const string_obj = rzig.strings.getString(char_vec, 0);

    const ext_ptr = rzig.pointers.makeExternalPtr(@ptrCast(@constCast(&string_obj)), r_null.*, r_null.*);

    rzig.vec.setListObj(results, 0, rzig.vec.asScalarVector(list.?.isTypeOf(.List)));
    rzig.vec.setListObj(results, 1, rzig.vec.asScalarVector(r_null.*.?.isTypeOf(.NULL)));
    rzig.vec.setListObj(results, 2, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 0).?.isTypeOf(.Symbol)));
    rzig.vec.setListObj(results, 3, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 1).?.isTypeOf(.Pairlist)));
    rzig.vec.setListObj(results, 4, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 2).?.isTypeOf(.Closure)));
    rzig.vec.setListObj(results, 5, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 3).?.isTypeOf(.Environment)));
    rzig.vec.setListObj(results, 6, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 4).?.isTypeOf(.LanguageObject)));
    rzig.vec.setListObj(results, 7, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 5).?.isTypeOf(.SpecialFunction)));
    rzig.vec.setListObj(results, 8, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 6).?.isTypeOf(.BuiltinFunction)));
    rzig.vec.setListObj(results, 9, rzig.vec.asScalarVector(string_obj.?.isTypeOf(.String)));
    rzig.vec.setListObj(results, 10, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 8).?.isTypeOf(.LogicalVector)));
    rzig.vec.setListObj(results, 11, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 9).?.isTypeOf(.IntegerVector)));
    rzig.vec.setListObj(results, 12, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 10).?.isTypeOf(.NumericVector)));
    rzig.vec.setListObj(results, 13, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 11).?.isTypeOf(.ComplexVector)));
    rzig.vec.setListObj(results, 14, rzig.vec.asScalarVector(rzig.vec.getListObj(list.?, 12).?.isTypeOf(.Expression)));
    rzig.vec.setListObj(results, 15, rzig.vec.asScalarVector(char_vec.?.isTypeOf(.CharacterVector)));
    rzig.vec.setListObj(results, 16, rzig.vec.asScalarVector(ext_ptr.?.isTypeOf(.ExternalPointer)));

    return results;
}
