//! R memory allocators wrappers

const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const RAssert = @import("errors.zig").RAssert;

const Allocator = mem.Allocator;

const r = @import("r.zig");

/// Points to start of allocated region for free and resize.
/// Following implementation of `std.heap.c_allocator`.
fn getHeader(ptr: [*]u8) *[*]u8 {
    return @as(*[*]u8, @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)));
}

/// Wrapper to R's memory allocator.
/// Implements the `std.mem.Allocator` interface.
/// The underlying allocator is very similar to C's `malloc` but provides R error signaling.
///
/// User must free memory. It is not freed by R's GC.
pub const r_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &r_allocator_vtable,
};

const r_allocator_vtable: Allocator.VTable = .{
    .alloc = RCalloc,
    .resize = RRealloc,
    .free = RFree,
};

/// Following implementation of `std.heap.c_allocator`.
/// R's allocator is an interace to malloc() but with R error signaling.
///
/// Caller should free memory.
/// It is not freed by R's GC.
fn RCalloc(ctx: *anyopaque, size: usize, ptr_align_exp: u8, ret_addr: usize) ?[*]u8 {
    _ = ctx;
    _ = ret_addr;

    RAssert(size > 0, "trying to allocate 0 bytes");

    const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(ptr_align_exp));

    // Following implementation example in `std.heap.c_allocator`
    const unaligned_ptr: [*]u8 = @ptrCast(r.R_chk_calloc(size + alignment - 1 + @sizeOf(usize), 1) orelse return null);
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment);
    const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
    getHeader(aligned_ptr).* = unaligned_ptr;

    return aligned_ptr;
}

fn RRealloc(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
    _ = ctx;
    _ = buf_align;
    _ = ret_addr;

    RAssert(new_len > 0, "trying to resize to 0 bytes");

    // Shrinking retains the same address
    // Always refuse to resize in-place, R's realloc may invalidate the pointer
    if (new_len <= buf.len) {
        return true;
    } else {
        return false;
    }
}

fn RFree(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
    _ = buf_align;
    _ = ctx;
    _ = ret_addr;

    const unaligned_ptr = getHeader(buf.ptr).*;
    r.R_chk_free(unaligned_ptr);
}

test "allocation print" {
    const result = try std.process.Child.run(.{
        .allocator = testing.allocator,
        .argv = &.{
            "Rscript",
            "--vanilla",
            "-e",
            "dyn.load('zig-out/tests/lib/libRtests.so'); .Call('testAllocPrint');",
        },
    });

    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    const expected =
        \\XXXXXXXXXX
        \\NULL
        \\
    ;

    testing.expectEqualSlices(u8, expected, result.stdout) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };
}

test "allocation, resize, print" {
    const result = try std.process.Child.run(.{
        .allocator = testing.allocator,
        .argv = &.{
            "Rscript",
            "--vanilla",
            "-e",
            "dyn.load('zig-out/tests/lib/libRtests.so'); .Call('testAllocResizePrint');",
        },
    });

    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    const expected =
        \\Expecting this message when resizing
        \\{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
        \\NULL
        \\
    ;

    testing.expectEqualSlices(u8, expected, result.stdout) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };
}

test "R stack allocation" {
    const result = try std.process.Child.run(.{
        .allocator = testing.allocator,
        .argv = &.{
            "Rscript",
            "--vanilla",
            "-e",
            "dyn.load('zig-out/tests/lib/libRtests.so'); .Call('testRCheckStack');",
        },
    });

    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    std.debug.print("{s}", .{result.stderr});

    try testing.expectStringStartsWith(result.stderr, "Error: C stack usage");
    try testing.expectStringEndsWith(result.stderr, "is too close to the limit\nExecution halted\n");
}
