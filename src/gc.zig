//! GC related

const r = @import("r.zig");
const Robject = @import("Rzig.zig").Robject;
const RAssert = @import("errors.zig").RAssert;

const std = @import("std");
const math = std.math;
const testing = std.testing;

const ProtectError = error{
    StackOverflow,
    UnprotectTooMany,
    IndexOutOfBounds,
};

pub const ProtectIndex = r.PROTECT_INDEX;

/// Must be used with R objects to protect them for GC while calling R API functions.
///
/// `size` is shared among ProtectStack instances.
/// Max size is 10_000.
pub const ProtectStack = struct {
    pub const protect_stack_size: usize = 10_000; // https://cran.r-project.org/doc/manuals/R-exts.html#Garbage-Collection

    var size: usize = 0; // static memory

    pub fn init() ProtectStack {
        return .{};
    }

    /// Unprotects all references from the stack.
    /// the stack can be reused.
    pub fn deinit(self: *ProtectStack) void {
        self.unprotect(ProtectStack.size) catch unreachable;
    }

    /// Pass an Robject, and get a GC protected Robject.
    /// Caller responsible to unprotect.
    ///
    /// Asserts protect stack will not overflow (default protect stack size 10000).
    pub fn protect(self: *ProtectStack, obj: Robject) ProtectError!Robject {
        _ = self;

        if (ProtectStack.size >= protect_stack_size) {
            return ProtectError.StackOverflow;
        }
        ProtectStack.size += 1;
        const out = r.Rf_protect(obj);
        return out;
    }

    /// Unprotect `n` objects from the stack.
    /// Asserts `n` is not larger than number of protected objects.
    pub fn unprotect(self: *ProtectStack, n: usize) ProtectError!void {
        _ = self;
        if (n > ProtectStack.size) {
            return ProtectError.UnprotectTooMany;
        }

        RAssert(n < math.maxInt(c_int), "cannot cast `n` to c_int. `n` value is larger than max `c_int`");

        r.Rf_unprotect(@intCast(n));
    }

    /// Protect an Robject from GC.
    /// Returns index of the object in the internal protect stack.
    /// Index is used used with `ProtectIndex.reprotect`.
    ///
    /// Asserts protect stack will not overflow (default protect stack size 10000).
    pub fn protectWithIndex(self: *ProtectStack, obj: Robject) ProtectError!usize {
        _ = self;
        if (ProtectStack.size >= protect_stack_size) {
            return ProtectError.StackOverflow;
        }

        const idx: ProtectIndex = undefined;

        r.R_ProtectWithIndex(obj, &idx);

        RAssert(idx < 0, "negative index value");

        return @intCast(idx);
    }

    /// Swap protection of new Robject with Robject in provided protect stack index
    ///
    /// Provided index is bounds checked.
    /// Object position in protect stack does not change by this call.
    pub fn reprotect(self: *ProtectStack, obj: Robject, protect_index: usize) ProtectError!void {
        _ = self;
        if (protect_index > ProtectStack.size) {
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
}
