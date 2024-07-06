const r = @import("Rzig");

const Robject = r.Robject;

export fn helloWorld() Robject {
    const stdout = r.io.RStdoutWriter().writer();
    stdout.print("Hello, World!", .{}) catch r.errors.stop("Failed to print!", .{});
    return r.r_null.*;
}
