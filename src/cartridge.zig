/// Representation of a cartridge header.
/// Memory layout is guranteed.
pub const CartridgeHeader = extern struct {
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
    cartridge_type: u8,
    /// ROM size (32KiB * 2^N)
    rom_size: u8,
    /// SRAM Size
    sram_size: u8,
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

    pub fn from_bytes(bytes: [@sizeOf(@This())]u8) @This() {
        return @as(CartridgeHeader, @bitCast(bytes));
    }
};

test "struct CartridgeHeader" {
    try expect(@sizeOf(CartridgeHeader) == 80);

    const bytes: [@sizeOf(CartridgeHeader)]u8 =
        [_]u8{ 0x01, 0x02, 0x03, 0x04 } // entry point
    ++ ([_]u8{0xFF} ** 48) // logo
    ++ @as([11]u8, "TestCartRid".*) // title
    ++ @as([4]u8, "ABCD".*) // maker
    ++ [_]u8{ 0x01, 0x78, 0x56, 0x00 } // cgb_flag, new_license, sgb_flag
    ++ [_]u8{ 0x03, 0x30, 0x50, 0x00 } // cartridge_type, rom_size, sram_size, destination
    ++ [_]u8{ 0x33, 0x00, 0x99, 0xAA, 0xBB } // old_license, game_version, header_checksum, global_checksum
    ;
    const header = CartridgeHeader.from_bytes(bytes);

    const header_answer = CartridgeHeader{
        .entry_point = 0x04030201,
        .logo = [_]u8{0xFF} ** 48,
        .title = "TestCartRid".*,
        .maker = "ABCD".*,
        .cgb_flag = 0x01,
        .new_license = 0x5678,
        .sgb_flag = 0x00,
        .cartridge_type = 0x03,
        .rom_size = 0x30,
        .sram_size = 0x50,
        .destination = 0x00,
        .old_license = 0x33,
        .game_version = 0x00,
        .header_checksum = 0x99,
        .global_checksum = 0xBBAA,
    };

    try expect(std.meta.eql(header, header_answer));
}

const std = @import("std");
const expect = std.testing.expect;
