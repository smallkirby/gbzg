const std = @import("std");

pub const Bootrom = struct {
    rom: []u8,
    active: bool = true,

    pub fn new(rom: []u8) Bootrom {
        return Bootrom{
            .rom = rom,
        };
    }

    pub fn read(self: Bootrom, addr: u16) u8 {
        return self.rom[addr];
    }

    pub fn write(self: *Bootrom, addr: u16, val: u8) void {
        if (addr != 0xFF50) {
            unreachable;
        }
        self.active = val == 0x00;
    }
};

const expect = @import("std").testing.expect;

test "bootrom simple read" {
    var rom = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05 };
    const bootrom = Bootrom.new(&rom);

    try expect(bootrom.read(0x00) == 0x00);
    try expect(bootrom.read(0x01) == 0x01);
    try expect(bootrom.read(0x02) == 0x02);
    try expect(bootrom.read(0x03) == 0x03);
    try expect(bootrom.read(0x04) == 0x04);
    try expect(bootrom.read(0x05) == 0x05);
}

test "bootrom activate" {
    var rom = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05 };
    var bootrom = Bootrom.new(&rom);

    try expect(bootrom.active == true);
    bootrom.write(0xFF50, 0x01);
    try expect(bootrom.active == false);
    bootrom.write(0xFF50, 0x00);
    try expect(bootrom.active == true);
}
