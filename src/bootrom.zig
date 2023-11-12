const Bootrom = struct {
    rom: [*]u8,

    pub fn new(rom: [*]u8) Bootrom {
        return Bootrom{ .rom = rom };
    }

    pub fn read(self: Bootrom, addr: u16) u8 {
        return self.rom[addr];
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
