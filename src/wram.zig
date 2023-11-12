const gbzg = @import("gbzg.zig");

pub const WRam = struct {
    ram: []u8,

    pub fn new() !WRam {
        const ram = try gbzg.wram_allocator.alloc([128]u8, 1);
        const wram = WRam{
            .ram = &ram[0],
        };
        wram.clear();
        return wram;
    }

    fn clear(self: WRam) void {
        for (self.ram) |*byte| {
            byte.* = 0;
        }
    }

    pub fn write(self: WRam, addr: u16, val: u8) void {
        self.ram[addr] = val;
    }

    pub fn read(self: WRam, addr: u16) u8 {
        return self.ram[addr];
    }
};

const expect = @import("std").testing.expect;
const memEql = @import("std").mem.eql;

test "WRAM cleared" {
    const wram = try WRam.new();
    const all_zero = [_]u8{0} ** 128;
    try expect(memEql(u8, wram.ram, &all_zero));
}

test "WRAM simple IO" {
    const wram = try WRam.new();

    wram.write(0x00, 0x01);
    wram.write(0x01, 0x02);
    wram.write(0x10, 0xFF);

    try expect(wram.read(0x00) == 0x01);
    try expect(wram.read(0x01) == 0x02);
    try expect(wram.read(0x10) == 0xFF);
    try expect(wram.read(0x11) == 0x00);
}
