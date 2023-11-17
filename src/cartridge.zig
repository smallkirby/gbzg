pub const CartridgeType = enum(u8) {
    ROMOnly = 0x00,
    MBC1 = 0x01,
    MBC1_SRAM = 0x02,
    MBC1_SRAM_BATT = 0x03,
    ROM_SRAM = 0x08,
    ROM_SRAM_BATT = 0x09,
    _,
};

/// Representation of a cartridge header.
/// Memory layout is guranteed.
pub const CartridgeHeader = extern struct {
    const SRAM_SIZE_TYPE = enum(u8) {
        _NONE = 0x00,
        _2KB = 0x01,
        _8KB = 0x02,
        _32KB = 0x03,
        _128KB = 0x04,
        _64KB = 0x05,
    };

    /// Entry point
    entry_point: u32,
    /// Compressed Nintendo logo
    logo: [48]u8,
    /// ASCII game title
    title: [11]u8,
    /// Maker Code in ASCII
    maker: [4]u8,
    /// Whether if CGB mode is requested
    cgb_flag: u8,
    /// Publisher code
    new_license: u16,
    /// Whether if SGB mode is requested
    sgb_flag: u8,
    /// Cartridge type (HW architecture info)
    cartridge_type: CartridgeType,
    /// ROM size (32KiB * 2^N)
    raw_rom_size: u8,
    /// SRAM Size
    raw_sram_size: SRAM_SIZE_TYPE,
    /// Whether if the cartridge is for abroad
    destination: u8,
    /// Publisher code (for old games)
    old_license: u8,
    /// 0
    game_version: u8,
    /// Header checksum
    header_checksum: u8,
    /// Chceksum of the whole cardridge ROM
    global_checksum: u16,

    /// Instantiate from a raw image.
    pub fn from_bytes(bytes: [@sizeOf(@This())]u8) @This() {
        const ret = @as(CartridgeHeader, @bitCast(bytes));
        ret.check_header_checksum();
        return ret;
    }

    fn check_header_checksum(self: @This()) void {
        var sum: u8 = 0;
        const bytes: [@sizeOf(@This())]u8 = @bitCast(self);
        for (0x34..0x4D) |i| {
            sum +%= bytes[i];
        }

        if (sum != self.header_checksum) {
            std.log.err("Header checksum mismatch: expected {}, got {}\n", .{ self.header_checksum, sum });
            unreachable;
        }
    }

    fn debug_new() @This() {
        return @This(){
            .entry_point = 0x00000000,
            .logo = [_]u8{0xFF} ** 48,
            .title = "TestCartRid".*,
            .maker = "ABCD".*,
            .cgb_flag = 0x01,
            .new_license = 0x5678,
            .sgb_flag = 0x00,
            .cartridge_type = .MBC1_SRAM_BATT,
            .raw_rom_size = 0x0,
            .raw_sram_size = CartridgeHeader.SRAM_SIZE_TYPE._NONE,
            .destination = 0x00,
            .old_license = 0x33,
            .game_version = 0x00,
            .header_checksum = 0x99,
            .global_checksum = 0xBBAA,
        };
    }

    fn sram_size(self: @This()) usize {
        return switch (self.raw_sram_size) {
            ._NONE => 0,
            ._2KB => 0x0800,
            ._8KB => 0x2000,
            ._32KB => 0x8000,
            ._128KB => 0x20000,
            ._64KB => 0x10000,
        };
    }

    fn rom_size(self: @This()) usize {
        if (self.raw_rom_size > 0x08) {
            unreachable;
        }
        return @as(usize, 1) << @truncate(self.raw_rom_size + 15);
    }
};

test "struct CartridgeHeader" {
    try expect(@sizeOf(CartridgeHeader) == 80);

    var bytes: [@sizeOf(CartridgeHeader)]u8 =
        [_]u8{ 0x01, 0x02, 0x03, 0x04 } // entry point
    ++ ([_]u8{0xFF} ** 48) // logo
    ++ @as([11]u8, "TestCartRid".*) // title
    ++ @as([4]u8, "ABCD".*) // maker
    ++ [_]u8{ 0x01, 0x78, 0x56, 0x00 } // cgb_flag, new_license, sgb_flag
    ++ [_]u8{ 0x03, 0x30, 0x03, 0x00 } // cartridge_type, rom_size, sram_size, destination
    ++ [_]u8{ 0x33, 0x00, 0x99, 0xAA, 0xBB } // old_license, game_version, header_checksum, global_checksum
    ;
    var checksum: u8 = 0;
    for (0x34..0x4D) |i| {
        checksum +%= bytes[i];
    }
    bytes[0x4D] = checksum;
    const header = CartridgeHeader.from_bytes(bytes);

    const header_answer = CartridgeHeader{
        .entry_point = 0x04030201,
        .logo = [_]u8{0xFF} ** 48,
        .title = "TestCartRid".*,
        .maker = "ABCD".*,
        .cgb_flag = 0x01,
        .new_license = 0x5678,
        .sgb_flag = 0x00,
        .cartridge_type = .MBC1_SRAM_BATT,
        .raw_rom_size = 0x30,
        .raw_sram_size = CartridgeHeader.SRAM_SIZE_TYPE._32KB,
        .destination = 0x00,
        .old_license = 0x33,
        .game_version = 0x00,
        .header_checksum = checksum,
        .global_checksum = 0xBBAA,
    };

    try expect(std.meta.eql(header, header_answer));
}

test "ROM sizes" {
    var cartridge = CartridgeHeader.debug_new();

    // ROM
    try expect(cartridge.sram_size() == 0x0000);
    cartridge.raw_sram_size = ._2KB;
    try expect(cartridge.sram_size() == 0x0800);
    cartridge.raw_sram_size = ._8KB;
    try expect(cartridge.sram_size() == 0x2000);
    cartridge.raw_sram_size = ._32KB;
    try expect(cartridge.sram_size() == 0x8000);
    cartridge.raw_sram_size = ._128KB;
    try expect(cartridge.sram_size() == 0x20000);
    cartridge.raw_sram_size = ._64KB;
    try expect(cartridge.sram_size() == 0x10000);

    // SRAM
    try expect(cartridge.rom_size() == 0x8000);
    cartridge.raw_rom_size = 0x01;
    try expect(cartridge.rom_size() == 0x10000);
    cartridge.raw_rom_size = 0x02;
    try expect(cartridge.rom_size() == 0x20000);
    cartridge.raw_rom_size = 0x03;
    try expect(cartridge.rom_size() == 0x40000);
    cartridge.raw_rom_size = 0x04;
    try expect(cartridge.rom_size() == 0x80000);
}

const std = @import("std");
const expect = std.testing.expect;
