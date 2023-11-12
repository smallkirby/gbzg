comptime {
    _ = @import("hram.zig");
    _ = @import("wram.zig");
    _ = @import("bootrom.zig");
    _ = @import("gbzg.zig");

    @import("std").testing.refAllDecls(@This());
}
