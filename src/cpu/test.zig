comptime {
    _ = @import("register.zig");

    @import("std").testing.refAllDecls(@This());
}
