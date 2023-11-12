const gbzg = @import("gbzg.zig");

pub const HRam = struct {
    pub const size = 0x80;
    ram: []u8,

    pub fn new() !HRam {
        const ram = try gbzg.hram_allocator.alloc([HRam.size]u8, 1);
        const hram = HRam{
            .ram = &ram[0],
        };
        hram.clear();
        return hram;
    }

    fn clear(self: HRam) void {
        for (self.ram) |*byte| {
            byte.* = 0;
        }
    }

    pub fn write(self: HRam, addr: u16, val: u8) void {
        self.ram[addr & 0x7F] = val;
    }

    pub fn read(self: HRam, addr: u16) u8 {
        return self.ram[addr & 0x7F];
    }
};

const expect = @import("std").testing.expect;
const memEql = @import("std").mem.eql;

test "HRAM cleared" {
    const hram = try HRam.new();
    const all_zero = [_]u8{0} ** HRam.size;
    try expect(memEql(u8, hram.ram, &all_zero));
}

test "HRAM simple IO" {
    const hram = try HRam.new();

    hram.write(0x00, 0x01);
    hram.write(0x01, 0x02);
    hram.write(0x10, 0xFF);

    try expect(hram.read(0x00) == 0x01);
    try expect(hram.read(0x01) == 0x02);
    try expect(hram.read(0x10) == 0xFF);
    try expect(hram.read(0x11) == 0x00);
}
