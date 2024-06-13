//! R memory allocators wrappers

const std = @import("std");
const mem = std.mem;

const assert = std.debug.assert;

const Allocator = mem.Allocator;

const r = @import("r.zig");

/// Thin Wrapper to R's "Transient storage allocation".
/// R reclaims memory at the end of calls to `.C`, `.Call`, or `.External`.
/// User does not have to free memory.
///
/// free() is a no-op.
/// resize() is a no-op.
///
/// Memory returned is only guaranteed to be aligned as required for C double pointers
///
/// Reference: https://cran.r-project.org/doc/FAQ/R-exts.html#Transient-storage-allocation
pub const RTransientAllocator: Allocator = .{
    .ptr = undefined,
    .vtable = &transient_allocator_vtable,
};

const transient_allocator_vtable: Allocator.VTable = .{
    .alloc = rawRAlloc,
    .resize = Allocator.noResize,
    .free = Allocator.noFree,
};

fn rawRAlloc(ptr: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
    _ = ptr;
    _ = ret_addr;

    assert(len > 0); // trying to allocating 0 bytes
    const raw_out: ?[*]u8 = r.R_alloc(len, ptr_align);
    const out = raw_out orelse return null;
    // From R-exts doc:
    // "The memory returned is only guaranteed to be aligned as required for `double` pointers:
    // take precautions if casting to a pointer which needs more."
    assert(mem.isAligned(@intFromPtr(out), @alignOf(f64)));

    return out;
}
