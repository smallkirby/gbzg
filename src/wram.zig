//! WRAM (Work RAM) is an 8KiB internal memory.
//! Noth that CGB can usu additional 7 banks, meaning 32KiB total.
//! Bank is selected by writing to SVBK register (FF70).
//! cf. https://gbdev.io/pandocs/CGB_Registers.html#ff70--svbk-cgb-mode-only-wram-bank

const gbzg = @import("gbzg.zig");

pub const WRam = struct {
    /// Single bank size of WRAM (8KiB).
    pub const size = 0x2000;
    /// Number of banks in WRAM. (CGB only)
    pub const BANK_NUM = 8;

    rams: [*][size]u8,
    svbk: u8 = 0,

    pub fn new() !WRam {
        const ram: [*][size]u8 = @ptrCast(try gbzg.wram_allocator.alloc(u8, BANK_NUM * size));
        var wram = WRam{
            .rams = ram,
        };
        wram.clear();
        return wram;
    }

    fn clear(self: *@This()) void {
        for (0..BANK_NUM) |i| {
            for (0..size) |j| {
                self.rams[i][j] = 0;
            }
        }
    }

    pub fn write(self: *@This(), addr: u16, val: u8) void {
        switch (addr) {
            0xFF70 => self.svbk = val,
            0xC000...0xCFFF => self.rams[0][addr & 0x1FFF] = val,
            0xD000...0xDFFF => self.rams[@max(self.svbk & 0b111, 1)][addr & 0x0FFF] = val,
            else => unreachable,
        }
    }

    pub fn read(self: @This(), addr: u16) u8 {
        return switch (addr) {
            0xFF70 => self.svbk,
            0xC000...0xCFFF => self.rams[0][addr & 0x1FFF],
            0xD000...0xDFFF => self.rams[@max(self.svbk & 0b111, 1)][addr & 0x0FFF],
            else => unreachable,
        };
    }
};

const expect = @import("std").testing.expect;
const memEql = @import("std").mem.eql;

test "WRAM size" {
    try expect(@sizeOf(WRam) == 0x10);
}

test "WRAM cleared" {
    const wram = try WRam.new();
    const all_zero = [_]u8{0} ** WRam.size;
    try expect(memEql(u8, &wram.rams[0], &all_zero));
}

test "WRAM simple IO" {
    var wram = try WRam.new();

    // Bank0
    wram.write(0xC000 + 0x00, 0x01);
    wram.write(0xC000 + 0x01, 0x02);
    wram.write(0xC000 + 0x10, 0xFF);
    // Bank1
    wram.write(0xD000 + 0x10, 0x34);

    try expect(wram.read(0xC000 + 0x00) == 0x01);
    try expect(wram.read(0xC000 + 0x01) == 0x02);
    try expect(wram.read(0xC000 + 0x10) == 0xFF);
    try expect(wram.read(0xC000 + 0x11) == 0x00); // read from unwritten area
    try expect(wram.read(0xD000 + 0x10) == 0x34);
}
