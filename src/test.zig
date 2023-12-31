comptime {
    _ = @import("hram.zig");
    _ = @import("wram.zig");
    _ = @import("bootrom.zig");
    _ = @import("gbzg.zig");
    _ = @import("peripherals.zig");
    _ = @import("ppu.zig");
    _ = @import("lcd.zig");
    _ = @import("cartridge.zig");
    _ = @import("mbc.zig");
    _ = @import("interrupts.zig");
    _ = @import("timer.zig");
    _ = @import("joypad.zig");
    _ = @import("controller.zig");

    _ = @import("cpu/test.zig");
    _ = @import("render/sixel.zig");

    @import("std").testing.refAllDecls(@This());
}
