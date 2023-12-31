const CardridgeType = @import("cartridge.zig").CartridgeType;
const std = @import("std");

pub const Mbc = union(enum) {
    nombc: struct {},
    mbc1: Mbc1,

    pub const Mbc1 = struct {
        /// Whether SRAM is enabled. Mapped to 0x0000-0x1FFF of lower 4bits.
        sram_enabled: bool = false,
        /// Mapped to 0x2000-0x3FFF. Lower 5bits are used.
        low_bank: usize,
        /// Mapped to 0x4000-0x5FFF. Lower 2bits are used.
        high_bank: usize,
        /// Whether if addr is switched by bank. Mapped to 0x6000-0x7FFF. LSB is used.
        bank_mode: bool,
        /// Number of ROM banks.
        num_rom_banks: usize,
    };

    /// Instantiate a memory bank controller.
    pub fn new(cartridge_type: CardridgeType, num_rom_banks: usize) @This() {
        return switch (cartridge_type) {
            .MBC1, .MBC1_SRAM, .MBC1_SRAM_BATT => .{
                .mbc1 = Mbc1{
                    .sram_enabled = false,
                    .low_bank = 1, // must be initialized to 1
                    .high_bank = 0,
                    .bank_mode = false,
                    .num_rom_banks = num_rom_banks,
                },
            },
            .ROMOnly, .ROM_SRAM, .ROM_SRAM_BATT => .{
                .nombc = .{},
            },
            _ => {
                std.log.err("Unsupported cartridge type: {}", .{cartridge_type});
                unreachable;
            },
        };
    }

    /// Write to MBC is handled as register writes to control the MBC.
    pub fn write(self: *@This(), addr: u16, val: u8) void {
        switch (self.*) {
            .nombc => {},
            .mbc1 => |*mbc| switch (addr) {
                0x0000...0x1FFF => mbc.sram_enabled = (val & 0x0F) == 0x0A,
                0x2000...0x3FFF => mbc.low_bank = if (val & 0b1111 == 0b0000) b: {
                    break :b 0b0001; // write 1 instead if val is zero
                } else b: {
                    break :b val & 0b0001_1111;
                },
                0x4000...0x5FFF => mbc.high_bank = val & 0b11,
                0x6000...0x7FFF => mbc.bank_mode = val & 0b1 == 0b1,
                else => unreachable,
            },
        }
    }

    /// Get the address of cardridge switced by MBC.
    pub fn get_addr(self: @This(), addr: u16) usize {
        return switch (self) {
            .nombc => addr,
            .mbc1 => |mbc1| switch (addr) {
                // ROM. Only lower 14bits are used.
                0x0000...0x3FFF => if (mbc1.bank_mode) b: {
                    break :b (mbc1.high_bank << 19) | (addr & 0x3FFF);
                } else b: {
                    break :b addr & 0x3FFF;
                },
                // ROM. Only lower 14bits are used. If addr exceeds ROM size, it wraps around.
                0x4000...0x7FFF => (mbc1.high_bank << 19) |
                    ((mbc1.low_bank & (mbc1.num_rom_banks - 1)) << 14) |
                    (addr & 0x3FFF),
                // SRAM. Only lower 13bits are used.
                0xA000...0xBFFF => if (mbc1.bank_mode) b: {
                    break :b (mbc1.high_bank << 13) | (addr & 0x1FFF);
                } else b: {
                    break :b addr & 0x1FFF;
                },
                else => unreachable,
            },
        };
    }
};

test "MBC init" {
    const mbc = Mbc.new(.MBC1, 2);
    try expect(mbc == Mbc.mbc1);
    try expect(mbc != Mbc.nombc);

    const mbc1 = mbc.mbc1;
    try expect(mbc1.low_bank == 1);
    try expect(mbc1.high_bank == 0);
    try expect(mbc1.bank_mode == false);
    try expect(mbc1.num_rom_banks == 2);
}

test "MBC1 write" {
    var mbc = Mbc.new(.MBC1, 2);

    // SRAM enable
    try expect(mbc.mbc1.sram_enabled == false);
    mbc.write(0x0100, 0x0A);
    try expect(mbc.mbc1.sram_enabled == true);
    mbc.write(0x0100, 0x3D);
    try expect(mbc.mbc1.sram_enabled == false);
    mbc.write(0x0100, 0x2A);
    try expect(mbc.mbc1.sram_enabled == true);

    // low bank
    try expect(mbc.mbc1.low_bank == 1);
    mbc.write(0x2100, 0x00);
    try expect(mbc.mbc1.low_bank == 1);
    mbc.write(0x3FFF, 0b0011_1111);
    try expect(mbc.mbc1.low_bank == 0b0001_1111);
    mbc.write(0x2100, 0x00);
    try expect(mbc.mbc1.low_bank == 0b1);

    // high bank
    try expect(mbc.mbc1.high_bank == 0);
    mbc.write(0x4100, 0b0110_0111);
    try expect(mbc.mbc1.high_bank == 0b11);
    mbc.write(0x4100, 0b0000_0000);
    try expect(mbc.mbc1.high_bank == 0b00);

    // bank mode
    try expect(mbc.mbc1.bank_mode == false);
    mbc.write(0x6100, 0b0000_0001);
    try expect(mbc.mbc1.bank_mode == true);
    mbc.write(0x6100, 0b0000_0000);
    try expect(mbc.mbc1.bank_mode == false);
    mbc.write(0x6100, 0b1111_1110);
    try expect(mbc.mbc1.bank_mode == false);
}

test "MBC1 get_addr" {
    var mbc = Mbc.new(.MBC1, 2);
    mbc.mbc1.high_bank = 0b10;
    mbc.mbc1.low_bank = 0b10110;
    mbc.mbc1.num_rom_banks = 2;
    try expect(mbc.mbc1.bank_mode == false);

    // ROM1 (straight map)
    try expect(mbc.get_addr(0x1000) == 0x1000);
    // ROM2
    try expect(mbc.get_addr(0x4100) == 0x0100 | (0b10 << 19) | (0b00000 << 14));
    try expect(mbc.get_addr(0x7400) == 0x3400 | (0b10 << 19) | (0b00000 << 14));
    // SRAM (straight map)
    try expect(mbc.get_addr(0xA000) == 0x0000);

    mbc.mbc1.bank_mode = true;

    // ROM1
    try expect(mbc.get_addr(0x1230) == 0x1230 | (0b10 << 19));
    // ROM2
    try expect(mbc.get_addr(0x4100) == 0x0100 | (0b10 << 19) | (0b00000 << 14));
    try expect(mbc.get_addr(0x7400) == 0x3400 | (0b10 << 19) | (0b00000 << 14));
    // SRAM
    try expect(mbc.get_addr(0xA000) == 0x0000 | (0b10 << 13));
    try expect(mbc.get_addr(0xB000) == 0x1000 | (0b10 << 13));
}

const expect = @import("std").testing.expect;
