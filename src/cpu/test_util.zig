const Cpu = @import("cpu.zig").Cpu;
const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Cartridge = @import("../cartridge.zig").Cartridge;
const CartridgeHeader = @import("../cartridge.zig").CartridgeHeader;

pub fn t_init_peripherals() !Peripherals {
    const Bootrom = @import("../bootrom.zig").Bootrom;
    var img = [_]u8{ 0x00, 0x00 };
    const bootram = Bootrom.new(&img);
    const cart = try test_init_debug_cartridge();
    var peripherals = try Peripherals.new(bootram, cart);

    return peripherals;
}

fn test_init_debug_cartridge() !Cartridge {
    const rom_size: usize = 1 << 18;
    var header = CartridgeHeader{
        .entry_point = 0x04030201,
        .logo = [_]u8{0xFF} ** 48,
        .title = "TestCartRid".*,
        .maker = "ABCD".*,
        .cgb_flag = 0x01,
        .new_license = 0x5678,
        .sgb_flag = 0x00,
        .cartridge_type = .MBC1_SRAM_BATT,
        .raw_rom_size = 0x03,
        .raw_sram_size = ._32KB,
        .destination = 0x00,
        .old_license = 0x33,
        .game_version = 0x00,
        .header_checksum = 0,
        .global_checksum = 0xBBAA,
    };
    var checksum: u8 = 0;
    for (0x34..0x4D) |i| {
        checksum +%= @as([@sizeOf(CartridgeHeader)]u8, @bitCast(header))[i];
    }
    header.header_checksum = checksum;

    var rom = [_]u8{0x00} ** rom_size;
    for (0..@sizeOf(CartridgeHeader)) |i| {
        rom[i] = @as([@sizeOf(CartridgeHeader)]u8, @bitCast(header))[i];
    }

    return try Cartridge.new(&rom);
}
