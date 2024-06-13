//! References:
//!     https://cran.r-project.org/doc/manuals/R-ints.html
//!     https://cran.r-project.org/doc/manuals/R-exts.html

const r = @import("r.zig");

const std = @import("std");
const testing = std.testing;

// R data types
pub usingnamespace @import("types.zig");

// Internal R API exposed for convenience.
// Intention is to deprecate when library is complete.
pub const rapi = r;

// R memory allocators
pub const heap = @import("allocator.zig");
pub const print = @import("print.zig");

test "simple hello world function call" {
    const result = try std.process.Child.run(.{
        .allocator = testing.allocator,
        .argv = &.{
            "Rscript",
            "--vanilla",
            "-e",
            "dyn.load('zig-out/tests/lib/libRtests.so'); .Call('hello');",
        },
    });

    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    const expected =
        \\Hello, World!
        \\[1] TRUE
        \\
    ;

    testing.expectEqualStrings(expected, result.stdout) catch |err| {
        std.debug.print("stderr:\n{s}\n", .{result.stderr});
        return err;
    };
}

test {
    _ = @import("allocator.zig");
}
