/// All the available registers
pub const Registers = struct {
    pc: u16,
    sp: u16,
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: u8, // ZNHC0000: Z=Zero, N=Negative, H=Half-carry, C=Carry
    h: u8,
    l: u8,

    pub fn new() Registers {
        return Registers{
            .pc = 0,
            .sp = 0,
            .a = 0,
            .b = 0,
            .c = 0,
            .d = 0,
            .e = 0,
            .f = 0,
            .h = 0,
            .l = 0,
        };
    }

    // Convenience functions to access the registers as 16-bit values
    pub fn af(self: Registers) u16 {
        return (@as(u16, self.a) << 8) | self.f;
    }
    pub fn bc(self: Registers) u16 {
        return (@as(u16, self.b) << 8) | self.c;
    }
    pub fn de(self: Registers) u16 {
        return (@as(u16, self.d) << 8) | self.e;
    }
    pub fn hl(self: Registers) u16 {
        return (@as(u16, self.h) << 8) | self.l;
    }

    // Convenience functions to write the registers as 16-bit values
    pub fn write_af(self: *Registers, val: u16) void {
        self.a = @intCast(val >> 8);
        self.f = @intCast(val & 0xF0);
    }
    pub fn write_bc(self: *Registers, val: u16) void {
        self.b = @intCast(val >> 8);
        self.c = @intCast(val & 0xFF);
    }
    pub fn write_de(self: *Registers, val: u16) void {
        self.d = @intCast(val >> 8);
        self.e = @intCast(val & 0xFF);
    }
    pub fn write_hl(self: *Registers, val: u16) void {
        self.h = @intCast(val >> 8);
        self.l = @intCast(val & 0xFF);
    }

    // Convenience functions to access the flags
    pub fn zf(self: Registers) bool {
        return (self.f & 0b1000_0000) != 0;
    }
    pub fn nf(self: Registers) bool {
        return (self.f & 0b0100_0000) != 0;
    }
    pub fn hf(self: Registers) bool {
        return (self.f & 0b0010_0000) != 0;
    }
    pub fn cf(self: Registers) bool {
        return (self.f & 0b0001_0000) != 0;
    }

    // Convenience functions to set the flags
    pub fn set_zf(self: *Registers, v: bool) void {
        self.f = (self.f & 0b0111_1111) | (@as(u8, @intFromBool(v)) << 7);
    }
    pub fn set_nf(self: *Registers, v: bool) void {
        self.f = (self.f & 0b1011_1111) | (@as(u8, @intFromBool(v)) << 6);
    }
    pub fn set_hf(self: *Registers, v: bool) void {
        self.f = (self.f & 0b1101_1111) | (@as(u8, @intFromBool(v)) << 5);
    }
    pub fn set_cf(self: *Registers, v: bool) void {
        self.f = (self.f & 0b1110_1111) | (@as(u8, @intFromBool(v)) << 4);
    }
};

test "Basic register access" {
    var regs = Registers{
        .pc = 0x1234,
        .sp = 0x5678,
        .a = 0x9a,
        .b = 0xbc,
        .c = 0xde,
        .d = 0xf0,
        .e = 0x12,
        .f = 0b1010_0000,
        .h = 0x56,
        .l = 0x78,
    };

    // read the registers
    try expect(regs.af() == 0x9aa0);
    try expect(regs.bc() == 0xbcde);
    try expect(regs.de() == 0xf012);
    try expect(regs.hl() == 0x5678);
    try expect(regs.zf() == true);
    try expect(regs.nf() == false);
    try expect(regs.hf() == true);
    try expect(regs.cf() == false);

    // write the registers
    regs.write_af(0x1234);
    regs.write_bc(0x5678);
    regs.write_de(0x9abc);
    regs.write_hl(0xdef0);
    try expect(regs.af() == 0x1230);
    try expect(regs.bc() == 0x5678);
    try expect(regs.de() == 0x9abc);
    try expect(regs.hl() == 0xdef0);

    // flag access
    regs.set_zf(false);
    regs.set_nf(true);
    regs.set_hf(false);
    regs.set_cf(true);
    try expect(regs.zf() == false);
    try expect(regs.nf() == true);
    try expect(regs.hf() == false);
    try expect(regs.cf() == true);
}

const expect = @import("std").testing.expect;
