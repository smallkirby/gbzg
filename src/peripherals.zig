const Bootrom = @import("bootrom.zig").Bootrom;
const HRam = @import("hram.zig").HRam;
const WRam = @import("wram.zig").WRam;
const Ppu = @import("ppu.zig").Ppu;

/// Periperal devices and MMIO handler
pub const Peripherals = struct {
    bootrom: Bootrom,
    hram: HRam,
    wram: WRam,
    ppu: Ppu,

    pub fn new(bootrom: Bootrom) !Peripherals {
        return Peripherals{
            .bootrom = bootrom,
            .hram = try HRam.new(),
            .wram = try WRam.new(),
            .ppu = try Ppu.new(),
        };
    }

    pub fn read(self: Peripherals, addr: u16) u8 {
        return switch (addr) {
            0x0000...0x00FF => if (self.bootrom.active) {
                return self.bootrom.read(addr);
            } else {
                unreachable;
            },
            0x8000...0x9FFF => self.ppu.read(addr),
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
            0x8000...0x9FFF => self.ppu.write(addr, val),
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
    var peripherals = try Peripherals.new(bootrom);

    _ = peripherals;
}

test "Basic peripheral IO" {
    var rom = [_]u8{ 0x00, 0x00, 0x00, 0x00 };
    var bootrom = Bootrom.new(&rom);
    var peripherals = try Peripherals.new(bootrom);

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
