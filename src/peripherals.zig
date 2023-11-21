const Bootrom = @import("bootrom.zig").Bootrom;
const HRam = @import("hram.zig").HRam;
const WRam = @import("wram.zig").WRam;
const Ppu = @import("ppu.zig").Ppu;
const Timer = @import("timer.zig").Timer;
const Cartridge = @import("cartridge.zig").Cartridge;
const CartridgeHeader = @import("cartridge.zig").CartridgeHeader;
const Interrupts = @import("interrupts.zig").Interrupts;

/// Periperal devices and MMIO handler
pub const Peripherals = struct {
    bootrom: Bootrom,
    hram: HRam,
    wram: WRam,
    ppu: Ppu,
    cartridge: Cartridge,
    timer: Timer,

    pub fn new(bootrom: Bootrom, cartridge: Cartridge, color: bool) !Peripherals {
        return Peripherals{
            .bootrom = bootrom,
            .hram = try HRam.new(),
            .wram = try WRam.new(),
            .ppu = try Ppu.new(color),
            .cartridge = cartridge,
            .timer = Timer.new(),
        };
    }

    pub fn read(self: Peripherals, interrupts: *Interrupts, addr: u16) u8 {
        return switch (addr) {
            0x0000...0x00FF => if (self.bootrom.active) {
                return self.bootrom.read(addr);
            } else {
                return self.cartridge.read(addr);
            },
            0x0100...0x01FF => self.cartridge.read(addr),
            0x0200...0x08FF => if (self.bootrom.active and self.ppu.is_cgb) {
                return self.bootrom.read(addr);
            } else {
                return self.cartridge.read(addr);
            },
            0x0900...0x7FFF => self.cartridge.read(addr),
            0x8000...0x9FFF => self.ppu.read(addr),
            0xA000...0xBFFF => self.cartridge.read(addr),
            0xC000...0xDFFF => self.wram.read(addr),
            0xFE00...0xFE9F => self.ppu.read(addr),
            0xFF04...0xFF07 => self.timer.read(addr),
            0xFF0F => interrupts.read(addr),
            0xFF40...0xFF4B => self.ppu.read(addr),
            0xFF4F => self.ppu.read(addr),
            0xFF51...0xFF55 => self.ppu.read(addr),
            0xFF68...0xFF6B => self.ppu.read(addr),
            0xFF80...0xFFFE => self.hram.read(addr),
            0xFFFF => interrupts.read(addr),
            else => blk: {
                // @import("std").debug.print("Invalid peripheral read: [0x{X:0>4}]\n", .{addr});
                // unreachable;
                break :blk 0xFF;
            },
        };
    }

    pub fn write(self: *Peripherals, interrupts: *Interrupts, addr: u16, val: u8) void {
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
            0xFF04...0xFF07 => self.timer.write(addr, val),
            0xFF0F => interrupts.write(addr, val),
            0xFF40...0xFF4B => self.ppu.write(addr, val),
            0xFF4F => self.ppu.write(addr, val),
            0xFF50 => self.bootrom.write(addr, val),
            0xFF51...0xFF55 => self.ppu.write(addr, val),
            0xFF68...0xFF6B => self.ppu.write(addr, val),
            0xFF80...0xFFFE => self.hram.write(addr, val),
            0xFFFF => interrupts.write(addr, val),
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
    const cart = try Cartridge.debug_new();
    var peripherals = try Peripherals.new(bootrom, cart, false);

    _ = peripherals;
}

test "Basic peripheral IO" {
    var rom = [_]u8{ 0x00, 0x00, 0x00, 0x00 };
    var bootrom = Bootrom.new(&rom);
    const cart = try Cartridge.debug_new();
    var peripherals = try Peripherals.new(bootrom, cart, false);
    var ints = Interrupts.new();

    try expect(peripherals.read(&ints, 0x0000) == 0x00);
    try expect(peripherals.read(&ints, 0xC000) == 0x00);
    try expect(peripherals.read(&ints, 0xFF80) == 0x00);

    peripherals.write(&ints, 0xC000, 0x01);
    peripherals.write(&ints, 0xFF80, 0x02);
    peripherals.write(&ints, 0xFF50, 0x03);
    try expect(peripherals.read(&ints, 0xC000) == 0x01);
    try expect(peripherals.read(&ints, 0xFF80) == 0x02);
    try expect(peripherals.bootrom.active == false);
}
