const std = @import("std");

/// Interrupts
pub const Interrupts = struct {
    /// Interrupts Master Enable
    ime: bool = false,
    /// Interrupts Enable Flag
    int_flags: u8,
    /// Interrupts Request Flag
    int_enable: u8,

    pub const IntruptsEnableBits = enum(u8) {
        /// Requested when PPU enters VBlank mode
        VBLANK = 0b0000_0001,
        ///
        STAT = 0b0000_0010,
        /// Requested when the Timer's TIMA regiseter overflows
        TIMER = 0b0000_0100,
        /// Requested when a serial transfer completes
        SERIAL = 0b0000_1000,
        /// Requested when a joypad button is pressed
        JOYPAD = 0b0001_0000,
    };

    pub fn new() @This() {
        return @This(){
            .int_flags = 0,
            .int_enable = 0,
        };
    }

    /// Request an inturrupt.
    /// Cannot cancel or unset an inturrupt request.
    pub fn irq(self: *@This(), val: u8) void {
        self.int_flags |= val;
    }

    pub fn read(self: *@This(), addr: u16) u8 {
        return switch (addr) {
            0xFF0F => self.int_flags,
            0xFFFF => self.int_enable,
            else => unreachable,
        };
    }

    pub fn write(self: *@This(), addr: u16, val: u8) void {
        switch (addr) {
            0xFF0F => self.int_flags = val,
            0xFFFF => self.int_enable = val,
            else => unreachable,
        }
    }
};

test "irq" {
    const IEB = Interrupts.IntruptsEnableBits;
    var ints = Interrupts.new();

    ints.irq(@intFromEnum(IEB.VBLANK) | @intFromEnum(IEB.STAT));
    try expect(ints.int_flags == (@intFromEnum(IEB.VBLANK) | @intFromEnum(IEB.STAT)));
    ints.irq(@intFromEnum(IEB.TIMER));
    try expect(ints.int_flags == (@intFromEnum(IEB.VBLANK) | @intFromEnum(IEB.STAT) | @intFromEnum(IEB.TIMER)));
}

const expect = std.testing.expect;
