const r = @import("Rzig");

const Robject = r.Robject;

export fn helloWorld() Robject {
    const stdout = r.io.RStdoutWriter().writer();
    try stdout.print("Hello, World!", .{});
    return r.r_null.*;
}
