comptime {
    _ = @import("register.zig");
    _ = @import("cpu.zig");
    _ = @import("instruction.zig");
    _ = @import("operand.zig");
    _ = @import("decode.zig");

    @import("std").testing.refAllDecls(@This());
}
