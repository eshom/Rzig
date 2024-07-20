//! GC related

const std = @import("std");
const math = std.math;
const testing = std.testing;

const r = @import("r.zig");
const rzig = @import("Rzig.zig");

const Robject = rzig.Robject;
const RAssert = rzig.errors.RAssert;

const ProtectError = error{
    StackOverflow,
    UnprotectTooMany,
    IndexOutOfBounds,
};

const ProtectIndex = usize;

//TODO: Decide if I want "safe" and "unsafe" versions of the same thing.
//It might be better to just force error handling, but it's also annoying to type in extern functions.

/// Must be used with R objects to protect them from GC while calling R API functions.
///
/// Max size is 10_000.
pub const protect_stack = struct {
    const Self = protect_stack;
    pub const protect_stack_size: usize = 10_000; // https://cran.r-project.org/doc/manuals/R-exts.html#Garbage-Collection
    var size: usize = 0; // static memory

    /// Pass an Robject, and get a GC protected Robject.
    /// Caller responsible to unprotect.
    ///
    /// Asserts protect stack will not overflow (default protect stack size 10000).
    pub fn protect(obj: Robject) Robject {
        Self.size += 1;
        return r.Rf_protect(obj);
    }

    /// Pass an Robject, and get a GC protected Robject.
    /// Caller responsible to unprotect.
    ///
    /// Asserts protect stack will not overflow (default protect stack size 10000).
    pub fn protectSafe(obj: Robject) ProtectError!Robject {
        if (Self.size >= protect_stack_size) {
            return ProtectError.StackOverflow;
        }
        return Self.protect(obj);
    }

    /// Unprotect `n` objects from the stack.
    /// Asserts `n` is not larger than number of protected objects or max stack size.
    pub fn unprotectSafe(n: usize) ProtectError!void {
        if (n > Self.size) {
            return ProtectError.UnprotectTooMany;
        }

        RAssert(n < Self.protect_stack_size, "Cannot unprotect more than max stack size");

        Self.unprotect(n);
    }

    /// Unprotect `n` objects from the stack.
    /// no-op if `n` is larger than number of protected objects in stack.
    pub fn unprotect(n: usize) void {
        if (n > Self.size) {
            return;
        }

        Self.size -= n;
        r.Rf_unprotect(@intCast(n));
    }

    /// Unprotect one object from the stack.
    /// no-op if stack is empty.
    pub fn unprotectOnce() void {
        if (Self.size == 0) {
            return;
        }

        Self.unprotect(1);
    }

    /// Unprotects all references from the stack.
    pub fn unprotectAll() void {
        Self.unprotect(Self.size);
    }

    /// Protect an Robject from GC.
    /// Returns index of the object in the internal protect stack.
    /// Index is used used with `protect_stack.reprotect`.
    ///
    /// Asserts protect stack will not overflow (default protect stack size 10000).
    pub fn protectWithIndex(obj: Robject) ProtectError!ProtectIndex {
        if (Self.size >= protect_stack_size) {
            return ProtectError.StackOverflow;
        }

        const idx: ProtectIndex = undefined;

        Self.size += 1;
        r.R_ProtectWithIndex(obj, &idx);

        RAssert(idx < 0, "negative index value");

        return @intCast(idx);
    }

    /// Swap protection of new Robject with Robject in provided protect stack index
    ///
    /// Provided index is bounds checked.
    /// Object position in protect stack does not change by this call.
    pub fn reprotect(obj: Robject, protect_index: ProtectIndex) ProtectError!void {
        if (protect_index > protect_stack.size) {
            ProtectError.IndexOutOfBounds;
        }

        r.R_Reprotect(obj, @intCast(protect_index));
    }
};

test "allocate some vectors" {
    const code =
        \\dyn.load('zig-out/tests/lib/libRtests.so')
        \\.Call('testAllocateSomeVectors')
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
        \\[1] 0.5 0.5 0.5
        \\
        \\[[2]]
        \\[1] 0 0 0
        \\
        \\[[3]]
        \\[1] FALSE FALSE FALSE
        \\
        \\
    ;

    testing.expectEqualStrings(expected, result.stdout) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };

    try testing.expectEqualStrings("", result.stderr);
}
