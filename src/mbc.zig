const CardridgeType = @import("cartridge.zig").CartridgeType;
const std = @import("std");

pub const Mbc = union(enum) {
    nombc: struct {},
    mbc1: Mbc1,

    /// Instantiate MBC1.
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
            .ROMOnly, .ROM_SRAM, .ROM_SRAM_BATT => {
                std.log.err("Unsupported cartridge type: {}", .{cartridge_type});
                unreachable;
            },
            _ => unreachable,
        };
    }
};

pub const Mbc1 = struct {
    /// Whether SRAM is enabled. Mapped to 0x0000-0x1FFF of lower 4bits.
    sram_enabled: bool = false,
    /// Mapped to 0x2000-0x3FFF of lower 5bits.
    low_bank: usize,
    /// Mapped to 0x4000-0x5FFF of lower 2bits.
    high_bank: usize,
    /// Mapped to 0x6000-0x7FFF of lower 1bit.
    bank_mode: bool,
    /// Number of ROM banks.
    num_rom_banks: usize,
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

const expect = @import("std").testing.expect;
