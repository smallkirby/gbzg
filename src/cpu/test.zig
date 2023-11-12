comptime {
    _ = @import("register.zig");
    _ = @import("cpu.zig");

    @import("std").testing.refAllDecls(@This());
}
