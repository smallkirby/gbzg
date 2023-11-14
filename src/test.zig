comptime {
    _ = @import("hram.zig");
    _ = @import("wram.zig");
    _ = @import("bootrom.zig");
    _ = @import("gbzg.zig");
    _ = @import("peripherals.zig");
    _ = @import("ppu.zig");
    _ = @import("cpu/test.zig");

    @import("std").testing.refAllDecls(@This());
}
