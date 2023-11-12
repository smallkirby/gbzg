comptime {
    _ = @import("register.zig");
    _ = @import("cpu.zig");
    _ = @import("instruction.zig");

    @import("std").testing.refAllDecls(@This());
}
