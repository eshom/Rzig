//! GC related

const r = @import("r.zig");
const Robject = @import("Rzig.zig").Robject;
const RAssert = @import("errors.zig").RAssert;
const math = @import("std").math;

const ProtectError = error{
    StackOverflow,
    UnprotectTooMany,
    IndexOutOfBounds,
};

pub const ProtectIndex = r.PROTECT_INDEX;

pub const ProtectStack = struct {
    pub const protect_stack_size: usize = 10000; // https://cran.r-project.org/doc/manuals/R-exts.html#Garbage-Collection
    len: usize = 0,

    pub fn init() ProtectStack {
        return .{};
    }

    /// Pass an Robject, and get a GC protected Robject.
    /// Caller responsible to unprotect.
    ///
    /// Asserts protect stack will not overflow (default protect stack size 10000).
    pub fn protect(self: *ProtectStack, obj: Robject) ProtectError!Robject {
        if (self.len >= protect_stack_size) {
            return ProtectError.StackOverflow;
        }
        self.len += 1;
        const out = r.Rf_protect(obj);
        return out;
    }

    /// Unprotect `n` objects from the stack.
    /// Asserts `n` is not larger than number of protected objects.
    pub fn unprotect(self: *ProtectStack, n: usize) ProtectError!void {
        if (n > self.len) {
            return ProtectError.UnprotectTooMany;
        }

        RAssert(n > math.maxInt(c_int), "cannot cast `n` to c_int. `n` value is larger than max `c_int`");

        r.Rf_unprotect(@intCast(n));
    }

    /// Protect an Robject from GC.
    /// Returns index of the object in the internal protect stack.
    /// Index is used used with `ProtectIndex.reprotect`.
    ///
    /// Asserts protect stack will not overflow (default protect stack size 10000).
    pub fn protectWithIndex(self: *ProtectStack, obj: Robject) ProtectError!usize {
        if (self.len >= protect_stack_size) {
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
        if (protect_index > self.len) {
            ProtectError.IndexOutOfBounds;
        }

        r.R_Reprotect(obj, @intCast(protect_index));
    }
};
