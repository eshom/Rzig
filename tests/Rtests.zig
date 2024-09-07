const std = @import("std");
const math = std.math;

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
    };
    defer allocator.free(buf);

    const ptr_good = allocator.resize(buf, 20);
    if (!ptr_good) {
        rzig.errors.stop("In `testAllocResizePrint()`: problem resizing memory, unexpected invalid pointer address\n", .{});
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
}

export fn testStop2() Robject {
    rzig.errors.stop("." ** 1000 ++ "\n", .{});
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

    const list = rzig.vec.allocVector(.List, 3).protect();
    const numeric = rzig.vec.allocVector(.NumericVector, 3).protect();
    const ints = rzig.vec.allocVector(.IntegerVector, 3).protect();
    const logicals = rzig.vec.allocVector(.LogicalVector, 3).protect();

    for (numeric.toSlice(f64)) |*val| {
        val.* = 0.5;
    }

    for (ints.toSlice(i32)) |*val| {
        val.* = 0;
    }

    for (logicals.toU32SliceFromLogical()) |*val| {
        val.* = 0;
    }

    list.setListObj(0, numeric);
    list.setListObj(1, ints);
    list.setListObj(2, logicals);

    return list;
}

export fn testIsObjects(list: Robject) Robject {
    //TODO: Add type checks for the following more tricky types:
    // .Promise
    // .Tripledot
    // .Any, although it might not be supported as part of the official API.
    // .Bytecode
    // .WeakReference
    const results = rzig.vec.allocVector(.List, 19).protect();
    defer rzig.gc.protect_stack.unprotectAll();

    const char_vec = list.getListObj(7);
    const string_obj = rzig.strings.getString(char_vec, 0);

    const ext_ptr = rzig.pointers.makeExternalPtr(@ptrCast(@constCast(&string_obj)), r_null.*, r_null.*);

    results.setListObj(0, rzig.vec.asScalarVector(list.isTypeOf(.List)));
    results.setListObj(1, rzig.vec.asScalarVector(r_null.*.isTypeOf(.NULL)));
    results.setListObj(2, rzig.vec.asScalarVector(list.getListObj(0).isTypeOf(.Symbol)));
    results.setListObj(3, rzig.vec.asScalarVector(list.getListObj(1).isTypeOf(.Pairlist)));
    results.setListObj(4, rzig.vec.asScalarVector(list.getListObj(2).isTypeOf(.Closure)));
    results.setListObj(5, rzig.vec.asScalarVector(list.getListObj(3).isTypeOf(.Environment)));
    results.setListObj(6, rzig.vec.asScalarVector(list.getListObj(4).isTypeOf(.LanguageObject)));
    results.setListObj(7, rzig.vec.asScalarVector(list.getListObj(5).isTypeOf(.SpecialFunction)));
    results.setListObj(8, rzig.vec.asScalarVector(list.getListObj(6).isTypeOf(.BuiltinFunction)));
    results.setListObj(9, rzig.vec.asScalarVector(string_obj.isTypeOf(.String)));
    results.setListObj(10, rzig.vec.asScalarVector(list.getListObj(8).isTypeOf(.LogicalVector)));
    results.setListObj(11, rzig.vec.asScalarVector(list.getListObj(9).isTypeOf(.IntegerVector)));
    results.setListObj(12, rzig.vec.asScalarVector(list.getListObj(10).isTypeOf(.NumericVector)));
    results.setListObj(13, rzig.vec.asScalarVector(list.getListObj(11).isTypeOf(.ComplexVector)));
    results.setListObj(14, rzig.vec.asScalarVector(list.getListObj(12).isTypeOf(.Expression)));
    results.setListObj(15, rzig.vec.asScalarVector(char_vec.isTypeOf(.CharacterVector)));
    results.setListObj(16, rzig.vec.asScalarVector(ext_ptr.isTypeOf(.ExternalPointer)));
    results.setListObj(17, rzig.vec.asScalarVector(list.getListObj(13).isTypeOf(.RawVector)));
    results.setListObj(18, rzig.vec.asScalarVector(list.getListObj(14).isTypeOf(.Object)));

    return results;
}

export fn testAsScalarVector() Robject {
    const results = rzig.vec.allocVector(.List, 23).protect();
    defer rzig.gc.protect_stack.unprotectAll();

    results.setListObj(0, rzig.vec.asScalarVector(@as(f32, 1.32456e+32)));
    results.setListObj(1, rzig.vec.asScalarVector(@as(f32, -9.87123e-32)));
    results.setListObj(2, rzig.vec.asScalarVector(math.inf(f32)));
    results.setListObj(3, rzig.vec.asScalarVector(-math.inf(f32)));
    results.setListObj(4, rzig.vec.asScalarVector(math.nan(f32)));

    results.setListObj(5, rzig.vec.asScalarVector(@as(f64, -9.1e+300)));
    results.setListObj(6, rzig.vec.asScalarVector(@as(f64, 1.2e-300)));
    results.setListObj(7, rzig.vec.asScalarVector(math.inf(f64)));
    results.setListObj(8, rzig.vec.asScalarVector(-math.inf(f64)));
    results.setListObj(9, rzig.vec.asScalarVector(math.nan(f64)));

    results.setListObj(10, rzig.vec.asScalarVector(-9.1e+307));
    results.setListObj(11, rzig.vec.asScalarVector(1.2e-307));
    results.setListObj(12, rzig.vec.asScalarVector(1.0e+500)); // Inf
    results.setListObj(13, rzig.vec.asScalarVector(-1.0e+500)); // -Inf

    results.setListObj(14, rzig.vec.asScalarVector(5));
    results.setListObj(15, rzig.vec.asScalarVector(-5));
    results.setListObj(16, rzig.vec.asScalarVector(@as(u32, 4)));
    results.setListObj(17, rzig.vec.asScalarVector(@as(i32, -4)));
    results.setListObj(18, rzig.vec.asScalarVector(@as(u0, 0)));
    results.setListObj(19, rzig.vec.asScalarVector(@as(u150, 2_000_000_000)));
    results.setListObj(20, rzig.vec.asScalarVector(@as(i150, -2_000_000_000)));
    results.setListObj(21, rzig.vec.asScalarVector(true));
    results.setListObj(22, rzig.vec.asScalarVector(false));

    return results;
}

export fn testAsScalarVectorError() Robject {
    _ = rzig.vec.asScalarVector(2_000_000_000_000);
    unreachable;
}

export fn testLengthResize() Robject {
    defer rzig.gc.protect_stack.unprotectAll();
    var vector = rzig.vec.allocVector(.NumericVector, 10).protect();
    var lens: [6]usize = undefined;

    lens[0] = vector.length();
    lens[1] = vector.length32();

    vector = vector.resizeVec(5).protect();

    lens[2] = vector.length();
    lens[3] = vector.length32();

    vector = vector.resizeVec(100).protect();

    lens[4] = vector.length();
    lens[5] = vector.length32();

    const results = rzig.vec.allocVector(.IntegerVector, 6).protect();
    const results_slc = results.toSlice(i32);

    for (results_slc, lens) |*dest, src| {
        dest.* = @intCast(src);
    }

    return results;
}

export fn testAsVector() Robject {
    defer rzig.gc.protect_stack.unprotectAll();
    const numeric = rzig.vec.allocVector(.NumericVector, 3).protect();
    const result = rzig.vec.allocVector(.List, 2).protect();

    for (numeric.toSlice(f64), 1..4) |*val, num| {
        val.* = @as(f64, @floatFromInt(num)) * 1.5;
    }

    const integer = numeric.asVector(.IntegerVector).protect();

    result.setListObj(0, numeric);
    result.setListObj(1, integer);

    return result;
}

export fn testGetListElem(list: Robject) Robject {
    const nums = list.getListElem(i32, 0);

    const out = rzig.vec.allocVector(.IntegerVector, nums.len).protect();
    defer out.unprotect();
    const out_slc = out.toSlice(i32);

    for (out_slc, nums) |*dst, src| {
        dst.* = src * 2;
    }

    return out;
}

export fn testAsPrimitive(list: Robject) Robject {
    defer rzig.gc.protect_stack.unprotectAll();

    const out = rzig.vec.allocVector(.List, 5).protect();

    const real = list.getListObj(0).asPrimitive(f32);
    const f = list.getListObj(1).asPrimitive(bool);
    const num: u15 = @intCast(list.getListObj(2).asPrimitive(u50));
    const z: u8 = @intCast(list.getListObj(3).asVector(.IntegerVector).protect().asPrimitive(i32));

    const Z: []const u8 = &.{z};
    const Zchar = rzig.strings.makeString(Z);
    const char_vec = rzig.vec.allocVector(.CharacterVector, 1).protect();
    rzig.strings.setString(char_vec, 0, Zchar);

    out.setListObj(0, rzig.vec.asScalarVector(real));
    out.setListObj(1, rzig.vec.asScalarVector(f));
    out.setListObj(2, rzig.vec.asScalarVector(num));
    out.setListObj(3, rzig.vec.asScalarVector(z));
    out.setListObj(4, char_vec);

    return out;
}

export fn testGetEncoding(charvec: Robject) Robject {
    const enc = charvec.getString(0).getEncoding();
    return rzig.vec.asScalarVector(enc == .bytes);
}
