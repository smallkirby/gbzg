const std = @import("std");

/// Interrupts
pub const Interrupts = struct {
    /// Interrupts Master Enable
    ime: bool = false,
    /// Interrupts Enable Flag
    int_flags: u8,
    /// Interrupts Request Flag
    int_enable: u8,

    /// A bitfield of the interrupt enable bits.
    /// Smaller bits are higher priority.
    pub const InterruptsEnableBits = enum(u8) {
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

        _,

        pub fn get_highest(intr: u8) @This() {
            if (intr & @intFromEnum(InterruptsEnableBits.VBLANK) != 0) {
                return .VBLANK;
            } else if (intr & @intFromEnum(InterruptsEnableBits.STAT) != 0) {
                return .STAT;
            } else if (intr & @intFromEnum(InterruptsEnableBits.TIMER) != 0) {
                return .TIMER;
            } else if (intr & @intFromEnum(InterruptsEnableBits.SERIAL) != 0) {
                return .SERIAL;
            } else if (intr & @intFromEnum(InterruptsEnableBits.JOYPAD) != 0) {
                return .JOYPAD;
            } else {
                unreachable;
            }
        }
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

    pub fn get_interrupt(self: @This()) u8 {
        return self.int_flags & self.int_enable & 0b0001_1111;
    }
};

test "irq" {
    const IEB = Interrupts.InterruptsEnableBits;
    var ints = Interrupts.new();

    ints.irq(@intFromEnum(IEB.VBLANK) | @intFromEnum(IEB.STAT));
    try expect(ints.int_flags == (@intFromEnum(IEB.VBLANK) | @intFromEnum(IEB.STAT)));
    ints.irq(@intFromEnum(IEB.TIMER));
    try expect(ints.int_flags == (@intFromEnum(IEB.VBLANK) | @intFromEnum(IEB.STAT) | @intFromEnum(IEB.TIMER)));
}

const expect = std.testing.expect;
