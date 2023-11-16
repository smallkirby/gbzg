comptime {
    _ = @import("sixel.zig");

    @import("std").testing.refAllDecls(@This());
}
