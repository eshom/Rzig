const std = @import("std");
const rzig = @import("Rzig");

export fn hello() rzig.RObject {
    rzig.print.printf("Hello, World!\n");
    return rzig.asScalarVector(true) catch |err| {
        const str_err: [*:0]const u8 = @errorName(err);
        rzig.rapi.Rf_error("%s. Problem while calling `asScalarVector()`\n", str_err);
        unreachable;
    };
}

// export fn transient_alloc_print() rzig.RObject {
//
// }
