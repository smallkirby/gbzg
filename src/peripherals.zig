const Bootrom = @import("bootrom.zig").Bootrom;
const HRam = @import("hram.zig").HRam;
const WRam = @import("wram.zig").WRam;
const Ppu = @import("ppu.zig").Ppu;
const Cartridge = @import("cartridge.zig").Cartridge;
const CartridgeHeader = @import("cartridge.zig").CartridgeHeader;

/// Periperal devices and MMIO handler
pub const Peripherals = struct {
    bootrom: Bootrom,
    hram: HRam,
    wram: WRam,
    ppu: Ppu,
    cartridge: Cartridge,

    pub fn new(bootrom: Bootrom, cartridge: Cartridge) !Peripherals {
        return Peripherals{
            .bootrom = bootrom,
            .hram = try HRam.new(),
            .wram = try WRam.new(),
            .ppu = try Ppu.new(),
            .cartridge = cartridge,
        };
    }

    pub fn read(self: Peripherals, addr: u16) u8 {
        return switch (addr) {
            0x0000...0x00FF => if (self.bootrom.active) {
                return self.bootrom.read(addr);
            } else {
                return self.cartridge.read(addr);
            },
            0x0100...0x7FFF => self.cartridge.read(addr),
            0x8000...0x9FFF => self.ppu.read(addr),
            0xA000...0xBFFF => self.cartridge.read(addr),
            0xC000...0xDFFF => self.wram.read(addr),
            0xFE00...0xFE9F => self.ppu.read(addr),
            0xFF40...0xFF4B => self.ppu.read(addr),
            0xFF80...0xFFFE => self.hram.read(addr),
            else => blk: {
                // @import("std").debug.print("Invalid peripheral read: [0x{X:0>4}]\n", .{addr});
                // unreachable;
                break :blk 0xFF;
            },
        };
    }

    pub fn write(self: *Peripherals, addr: u16, val: u8) void {
        // @import("std").debug.print("write: [0x{X:0>4}] <- 0x{X:0>4}\n", .{ addr, val });
        return switch (addr) {
            0x0000...0x00FF => if (!self.bootrom.active) {
                self.cartridge.write(addr, val);
            },
            0x0100...0x7FFF => self.cartridge.write(addr, val),
            0x8000...0x9FFF => self.ppu.write(addr, val),
            0xA000...0xBFFF => self.cartridge.write(addr, val),
            0xC000...0xDFFF => self.wram.write(addr, val),
            0xFE00...0xFE9F => self.ppu.write(addr, val),
            0xFF40...0xFF4B => self.ppu.write(addr, val),
            0xFF50 => self.bootrom.write(addr, val),
            0xFF80...0xFFFE => self.hram.write(addr, val),
            else => {
                // TODO: should be unreachable
                // @import("std").io.getStdErr().writer().print("Unimplemented peripheral write: [0x{X:0>4}] <- 0x{X:0>4}\n", .{ addr, val }) catch {};
                // unreachable;
            },
        };
    }
};

const expect = @import("std").testing.expect;

test "Initialize peripherals" {
    var rom = [_]u8{ 0x00, 0x00, 0x00, 0x00 };
    var bootrom = Bootrom.new(&rom);
    const cart = try test_init_debug_cartridge();
    var peripherals = try Peripherals.new(bootrom, cart);

    _ = peripherals;
}

test "Basic peripheral IO" {
    var rom = [_]u8{ 0x00, 0x00, 0x00, 0x00 };
    var bootrom = Bootrom.new(&rom);
    const cart = try test_init_debug_cartridge();
    var peripherals = try Peripherals.new(bootrom, cart);

    try expect(peripherals.read(0x0000) == 0x00);
    try expect(peripherals.read(0xC000) == 0x00);
    try expect(peripherals.read(0xFF80) == 0x00);

    peripherals.write(0xC000, 0x01);
    peripherals.write(0xFF80, 0x02);
    peripherals.write(0xFF50, 0x03);
    try expect(peripherals.read(0xC000) == 0x01);
    try expect(peripherals.read(0xFF80) == 0x02);
    try expect(peripherals.bootrom.active == false);
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
