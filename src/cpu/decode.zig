//! Defines the decode of instruction set.
//! cf: https://izik1.github.io/gbops/index.html

const Cpu = @import("cpu.zig").Cpu;
const Peripherals = @import("../peripherals.zig").Peripherals;
const inst = @import("instruction.zig");
const Operand = @import("operand.zig").Operand;

/// Decode the current opcode and execute the instruction.
pub fn decode(cpu: *Cpu, bus: *Peripherals) void {
    switch (cpu.ctx.opcode) {
        0x00 => inst.nop(cpu, bus),
        0x10 => unreachable,
        0x20 => inst.jrc(cpu, bus, .NZ),
        0x30 => inst.jrc(cpu, bus, .NC),
        0x01 => inst.ld(cpu, bus, .{ .reg16 = .BC }, .{ .imm16 = .{} }),
        0x11 => inst.ld(cpu, bus, .{ .reg16 = .DE }, .{ .imm16 = .{} }),
        0x21 => inst.ld(cpu, bus, .{ .reg16 = .HL }, .{ .imm16 = .{} }),
        0x31 => inst.ld(cpu, bus, .{ .reg16 = .SP }, .{ .imm16 = .{} }),
        0x02 => inst.ld(cpu, bus, .{ .indirect = .BC }, .{ .reg8 = .A }),
        0x12 => inst.ld(cpu, bus, .{ .indirect = .DE }, .{ .reg8 = .A }),
        0x22 => inst.ld(cpu, bus, .{ .indirect = .HLI }, .{ .reg8 = .A }),
        0x32 => inst.ld(cpu, bus, .{ .indirect = .HLD }, .{ .reg8 = .A }),
        0x03 => inst.inc(cpu, bus, .{ .reg16 = .BC }),
        0x13 => inst.inc(cpu, bus, .{ .reg16 = .DE }),
        0x23 => inst.inc(cpu, bus, .{ .reg16 = .HL }),
        0x33 => inst.inc(cpu, bus, .{ .reg16 = .SP }),
        0x04 => inst.inc(cpu, bus, .{ .reg8 = .B }),
        0x14 => inst.inc(cpu, bus, .{ .reg8 = .D }),
        0x24 => inst.inc(cpu, bus, .{ .reg8 = .H }),
        0x34 => inst.inc(cpu, bus, .{ .indirect = .HL }),
        0x05 => inst.dec(cpu, bus, .{ .reg8 = .B }),
        0x15 => inst.dec(cpu, bus, .{ .reg8 = .D }),
        0x25 => inst.dec(cpu, bus, .{ .reg8 = .H }),
        0x35 => inst.dec(cpu, bus, .{ .indirect = .HL }),
        0x06 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .imm8 = .{} }),
        0x16 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .imm8 = .{} }),
        0x26 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .imm8 = .{} }),
        0x36 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .imm8 = .{} }),
        0x07, 0x17, 0x27, 0x37 => unreachable,
        0x08 => inst.ld(cpu, bus, .{ .direct16 = .{} }, .{ .reg16 = .SP }),
        0x18 => inst.jr(cpu, bus),
        0x28 => inst.jrc(cpu, bus, .Z),
        0x38 => inst.jrc(cpu, bus, .C),
        0x09, 0x19, 0x29, 0x39 => unreachable,
        0x0A => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .indirect = .BC }),
        0x1A => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .indirect = .DE }),
        0x2A => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .indirect = .HLI }),
        0x3A => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .indirect = .HLD }),
        0x0B => inst.dec(cpu, bus, .{ .reg16 = .BC }),
        0x1B => inst.dec(cpu, bus, .{ .reg16 = .DE }),
        0x2B => inst.dec(cpu, bus, .{ .reg16 = .HL }),
        0x3B => inst.dec(cpu, bus, .{ .reg16 = .SP }),
        0x0C => inst.inc(cpu, bus, .{ .reg8 = .C }),
        0x1C => inst.inc(cpu, bus, .{ .reg8 = .E }),
        0x2C => inst.inc(cpu, bus, .{ .reg8 = .L }),
        0x3C => inst.inc(cpu, bus, .{ .reg8 = .A }),
        0x0D => inst.dec(cpu, bus, .{ .reg8 = .C }),
        0x1D => inst.dec(cpu, bus, .{ .reg8 = .E }),
        0x2D => inst.dec(cpu, bus, .{ .reg8 = .L }),
        0x3D => inst.dec(cpu, bus, .{ .reg8 = .A }),
        0x0E => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .imm8 = .{} }),
        0x1E => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .imm8 = .{} }),
        0x2E => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .imm8 = .{} }),
        0x3E => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .imm8 = .{} }),
        0x0F, 0x1F, 0x2F, 0x3F => unreachable,
        0x40 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .reg8 = .B }),
        0x50 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .reg8 = .B }),
        0x60 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .reg8 = .B }),
        0x70 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .reg8 = .B }),
        0x41 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .reg8 = .C }),
        0x51 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .reg8 = .C }),
        0x61 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .reg8 = .C }),
        0x71 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .reg8 = .C }),
        0x42 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .reg8 = .D }),
        0x52 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .reg8 = .D }),
        0x62 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .reg8 = .D }),
        0x72 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .reg8 = .D }),
        0x43 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .reg8 = .E }),
        0x53 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .reg8 = .E }),
        0x63 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .reg8 = .E }),
        0x73 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .reg8 = .E }),
        0x44 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .reg8 = .H }),
        0x54 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .reg8 = .H }),
        0x64 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .reg8 = .H }),
        0x74 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .reg8 = .H }),
        0x45 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .reg8 = .L }),
        0x55 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .reg8 = .L }),
        0x65 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .reg8 = .L }),
        0x75 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .reg8 = .L }),
        0x46 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .indirect = .HL }),
        0x56 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .indirect = .HL }),
        0x66 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .indirect = .HL }),
        0x76 => inst.halt(cpu, bus),
        0x47 => inst.ld(cpu, bus, .{ .reg8 = .B }, .{ .reg8 = .A }),
        0x57 => inst.ld(cpu, bus, .{ .reg8 = .D }, .{ .reg8 = .A }),
        0x67 => inst.ld(cpu, bus, .{ .reg8 = .H }, .{ .reg8 = .A }),
        0x77 => inst.ld(cpu, bus, .{ .indirect = .HL }, .{ .reg8 = .A }),
        0x48 => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .reg8 = .B }),
        0x58 => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .reg8 = .B }),
        0x68 => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .reg8 = .B }),
        0x78 => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .reg8 = .B }),
        0x49 => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .reg8 = .C }),
        0x59 => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .reg8 = .C }),
        0x69 => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .reg8 = .C }),
        0x79 => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .reg8 = .C }),
        0x4A => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .reg8 = .D }),
        0x5A => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .reg8 = .D }),
        0x6A => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .reg8 = .D }),
        0x7A => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .reg8 = .D }),
        0x4B => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .reg8 = .E }),
        0x5B => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .reg8 = .E }),
        0x6B => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .reg8 = .E }),
        0x7B => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .reg8 = .E }),
        0x4C => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .reg8 = .H }),
        0x5C => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .reg8 = .H }),
        0x6C => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .reg8 = .H }),
        0x7C => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .reg8 = .H }),
        0x4D => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .reg8 = .L }),
        0x5D => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .reg8 = .L }),
        0x6D => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .reg8 = .L }),
        0x7D => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .reg8 = .L }),
        0x4E => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .indirect = .HL }),
        0x5E => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .indirect = .HL }),
        0x6E => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .indirect = .HL }),
        0x7E => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .indirect = .HL }),
        0x4F => inst.ld(cpu, bus, .{ .reg8 = .C }, .{ .reg8 = .A }),
        0x5F => inst.ld(cpu, bus, .{ .reg8 = .E }, .{ .reg8 = .A }),
        0x6F => inst.ld(cpu, bus, .{ .reg8 = .L }, .{ .reg8 = .A }),
        0x7F => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .reg8 = .A }),
        0x80, 0x90, 0xA0, 0xB0 => unreachable,
        0x81, 0x91, 0xA1, 0xB1 => unreachable,
        0x82, 0x92, 0xA2, 0xB2 => unreachable,
        0x83, 0x93, 0xA3, 0xB3 => unreachable,
        0x84, 0x94, 0xA4, 0xB4 => unreachable,
        0x85, 0x95, 0xA5, 0xB5 => unreachable,
        0x86, 0x96, 0xA6, 0xB6 => unreachable,
        0x87, 0x97, 0xA7, 0xB7 => unreachable,
        0x88, 0x98, 0xA8, 0xB8 => unreachable,
        0x89, 0x99, 0xA9, 0xB9 => unreachable,
        0x8A, 0x9A, 0xAA, 0xBA => unreachable,
        0x8B, 0x9B, 0xAB, 0xBB => unreachable,
        0x8C, 0x9C, 0xAC, 0xBC => unreachable,
        0x8D, 0x9D, 0xAD, 0xBD => unreachable,
        0x8E, 0x9E, 0xAE, 0xBE => unreachable,
        0x8F, 0x9F, 0xAF, 0xBF => unreachable,
        0xC0, 0xD0 => unreachable,
        0xE0 => inst.ld(cpu, bus, .{ .direct8 = .DFF }, .{ .reg8 = .A }),
        0xF0 => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .direct8 = .DFF }),
        0xC1 => inst.pop(cpu, bus, .{ .reg16 = .BC }),
        0xD1 => inst.pop(cpu, bus, .{ .reg16 = .DE }),
        0xE1 => inst.pop(cpu, bus, .{ .reg16 = .HL }),
        0xF1 => inst.pop(cpu, bus, .{ .reg16 = .AF }),
        0xC2, 0xD2 => unreachable,
        0xE2 => inst.ld(cpu, bus, .{ .indirect = .CFF }, .{ .reg8 = .A }),
        0xF2 => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .indirect = .CFF }),
        0xC3, 0xD3, 0xE3 => unreachable,
        0xF3 => inst.di(cpu, bus),
        0xC4, 0xE4, 0xF4 => unreachable,
        0xC5 => inst.push(cpu, bus, .{ .reg16 = .BC }),
        0xD5 => inst.push(cpu, bus, .{ .reg16 = .DE }),
        0xE5 => inst.push(cpu, bus, .{ .reg16 = .HL }),
        0xF5 => inst.push(cpu, bus, .{ .reg16 = .AF }),
        0xC6, 0xD6, 0xE6, 0xF6, 0xC7, 0xD7, 0xE7, 0xF7 => unreachable,
        0xC8, 0xD8, 0xE8, 0xF8 => unreachable,
        0xC9 => inst.ret(cpu, bus),
        0xD9 => inst.reti(cpu, bus),
        0xE9, 0xF9 => unreachable,
        0xCA, 0xDA => unreachable,
        0xEA => inst.ld(cpu, bus, .{ .direct8 = .D }, .{ .reg8 = .A }),
        0xFA => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .direct8 = .D }),
        0xCB => cb_prefixed(cpu, bus),
        0xDB, 0xEB => unreachable,
        0xFB => inst.ei(cpu, bus),
        0xCC, 0xDC, 0xEC, 0xFC => unreachable,
        0xCD => inst.call(cpu, bus),
        0xDD, 0xED, 0xFD => unreachable,
        0xCE, 0xDE, 0xEE => unreachable,
        0xFE => inst.cp(cpu, bus, .{ .imm8 = .{} }),
        0xCF, 0xDF, 0xEF, 0xFF => unreachable,
        // TODO: change opcode bit width and do exhaustive check
        else => unreachable,
    }
}

/// Decode the current CB-prefixed opcode and execute the instruction.
pub fn cb_decode(cpu: *Cpu, bus: *Peripherals) void {
    switch (cpu.ctx.opcode) {
        0x00 => unreachable,
        0x10 => inst.rl(cpu, bus, .{ .reg8 = .B }),
        0x20, 0x30 => unreachable,
        0x01 => unreachable,
        0x11 => inst.rl(cpu, bus, .{ .reg8 = .C }),
        0x21 => unreachable,
        0x31 => unreachable,
        0x02 => unreachable,
        0x12 => inst.rl(cpu, bus, .{ .reg8 = .D }),
        0x22 => unreachable,
        0x32 => unreachable,
        0x03 => unreachable,
        0x13 => inst.rl(cpu, bus, .{ .reg8 = .E }),
        0x23 => unreachable,
        0x33 => unreachable,
        0x04 => unreachable,
        0x14 => inst.rl(cpu, bus, .{ .reg8 = .H }),
        0x24 => unreachable,
        0x34 => unreachable,
        0x05 => unreachable,
        0x15 => inst.rl(cpu, bus, .{ .reg8 = .L }),
        0x25 => unreachable,
        0x35 => unreachable,
        0x06 => unreachable,
        0x16 => inst.rl(cpu, bus, .{ .indirect = .HL }),
        0x26 => unreachable,
        0x36 => unreachable,
        0x07 => unreachable,
        0x17 => inst.rl(cpu, bus, .{ .reg8 = .A }),
        0x27 => unreachable,
        0x37 => unreachable,
        0x08, 0x18, 0x28, 0x38 => unreachable,
        0x09, 0x19, 0x29, 0x39 => unreachable,
        0x0A, 0x1A, 0x2A, 0x3A => unreachable,
        0x0B, 0x1B, 0x2B, 0x3B => unreachable,
        0x0C, 0x1C, 0x2C, 0x3C => unreachable,
        0x0D, 0x1D, 0x2D, 0x3D => unreachable,
        0x0E, 0x1E, 0x2E, 0x3E => unreachable,
        0x0F, 0x1F, 0x2F, 0x3F => unreachable,
        0x40 => inst.bit(cpu, bus, 0, .{ .reg8 = .B }),
        0x50 => inst.bit(cpu, bus, 2, .{ .reg8 = .B }),
        0x60 => inst.bit(cpu, bus, 4, .{ .reg8 = .B }),
        0x70 => inst.bit(cpu, bus, 6, .{ .reg8 = .B }),
        0x41 => inst.bit(cpu, bus, 0, .{ .reg8 = .C }),
        0x51 => inst.bit(cpu, bus, 2, .{ .reg8 = .C }),
        0x61 => inst.bit(cpu, bus, 4, .{ .reg8 = .C }),
        0x71 => inst.bit(cpu, bus, 6, .{ .reg8 = .C }),
        0x42 => inst.bit(cpu, bus, 0, .{ .reg8 = .D }),
        0x52 => inst.bit(cpu, bus, 2, .{ .reg8 = .D }),
        0x62 => inst.bit(cpu, bus, 4, .{ .reg8 = .D }),
        0x72 => inst.bit(cpu, bus, 6, .{ .reg8 = .D }),
        0x43 => inst.bit(cpu, bus, 0, .{ .reg8 = .E }),
        0x53 => inst.bit(cpu, bus, 2, .{ .reg8 = .E }),
        0x63 => inst.bit(cpu, bus, 4, .{ .reg8 = .E }),
        0x73 => inst.bit(cpu, bus, 6, .{ .reg8 = .E }),
        0x44 => inst.bit(cpu, bus, 0, .{ .reg8 = .H }),
        0x54 => inst.bit(cpu, bus, 2, .{ .reg8 = .H }),
        0x64 => inst.bit(cpu, bus, 4, .{ .reg8 = .H }),
        0x74 => inst.bit(cpu, bus, 6, .{ .reg8 = .H }),
        0x45 => inst.bit(cpu, bus, 0, .{ .reg8 = .L }),
        0x55 => inst.bit(cpu, bus, 2, .{ .reg8 = .L }),
        0x65 => inst.bit(cpu, bus, 4, .{ .reg8 = .L }),
        0x75 => inst.bit(cpu, bus, 6, .{ .reg8 = .L }),
        0x46 => inst.bit(cpu, bus, 0, .{ .indirect = .HL }),
        0x56 => inst.bit(cpu, bus, 2, .{ .indirect = .HL }),
        0x66 => inst.bit(cpu, bus, 4, .{ .indirect = .HL }),
        0x76 => inst.bit(cpu, bus, 6, .{ .indirect = .HL }),
        0x47 => inst.bit(cpu, bus, 0, .{ .reg8 = .A }),
        0x57 => inst.bit(cpu, bus, 2, .{ .reg8 = .A }),
        0x67 => inst.bit(cpu, bus, 4, .{ .reg8 = .A }),
        0x77 => inst.bit(cpu, bus, 6, .{ .reg8 = .A }),
        0x48 => inst.bit(cpu, bus, 1, .{ .reg8 = .B }),
        0x58 => inst.bit(cpu, bus, 3, .{ .reg8 = .B }),
        0x68 => inst.bit(cpu, bus, 5, .{ .reg8 = .B }),
        0x78 => inst.bit(cpu, bus, 7, .{ .reg8 = .B }),
        0x49 => inst.bit(cpu, bus, 1, .{ .reg8 = .C }),
        0x59 => inst.bit(cpu, bus, 3, .{ .reg8 = .C }),
        0x69 => inst.bit(cpu, bus, 5, .{ .reg8 = .C }),
        0x79 => inst.bit(cpu, bus, 7, .{ .reg8 = .C }),
        0x4A => inst.bit(cpu, bus, 1, .{ .reg8 = .D }),
        0x5A => inst.bit(cpu, bus, 3, .{ .reg8 = .D }),
        0x6A => inst.bit(cpu, bus, 5, .{ .reg8 = .D }),
        0x7A => inst.bit(cpu, bus, 7, .{ .reg8 = .D }),
        0x4B => inst.bit(cpu, bus, 1, .{ .reg8 = .E }),
        0x5B => inst.bit(cpu, bus, 3, .{ .reg8 = .E }),
        0x6B => inst.bit(cpu, bus, 5, .{ .reg8 = .E }),
        0x7B => inst.bit(cpu, bus, 7, .{ .reg8 = .E }),
        0x4C => inst.bit(cpu, bus, 1, .{ .reg8 = .H }),
        0x5C => inst.bit(cpu, bus, 3, .{ .reg8 = .H }),
        0x6C => inst.bit(cpu, bus, 5, .{ .reg8 = .H }),
        0x7C => inst.bit(cpu, bus, 7, .{ .reg8 = .H }),
        0x4D => inst.bit(cpu, bus, 1, .{ .reg8 = .L }),
        0x5D => inst.bit(cpu, bus, 3, .{ .reg8 = .L }),
        0x6D => inst.bit(cpu, bus, 5, .{ .reg8 = .L }),
        0x7D => inst.bit(cpu, bus, 7, .{ .reg8 = .L }),
        0x4E => inst.bit(cpu, bus, 1, .{ .indirect = .HL }),
        0x5E => inst.bit(cpu, bus, 3, .{ .indirect = .HL }),
        0x6E => inst.bit(cpu, bus, 5, .{ .indirect = .HL }),
        0x7E => inst.bit(cpu, bus, 7, .{ .indirect = .HL }),
        0x4F => inst.bit(cpu, bus, 1, .{ .reg8 = .A }),
        0x5F => inst.bit(cpu, bus, 3, .{ .reg8 = .A }),
        0x6F => inst.bit(cpu, bus, 5, .{ .reg8 = .A }),
        0x7F => inst.bit(cpu, bus, 7, .{ .reg8 = .A }),
        0x80, 0x90, 0xA0, 0xB0, 0x81, 0x91, 0xA1, 0xB1, 0x82, 0x92, 0xA2, 0xB2, 0x83, 0x93, 0xA3, 0xB3 => unreachable,
        0x84, 0x94, 0xA4, 0xB4, 0x85, 0x95, 0xA5, 0xB5, 0x86, 0x96, 0xA6, 0xB6, 0x87, 0x97, 0xA7, 0xB7 => unreachable,
        0x88, 0x98, 0xA8, 0xB8, 0x89, 0x99, 0xA9, 0xB9, 0x8A, 0x9A, 0xAA, 0xBA, 0x8B, 0x9B, 0xAB, 0xBB => unreachable,
        0x8C, 0x9C, 0xAC, 0xBC, 0x8D, 0x9D, 0xAD, 0xBD, 0x8E, 0x9E, 0xAE, 0xBE, 0x8F, 0x9F, 0xAF, 0xBF => unreachable,
        // TODO: change opcode bit width and do exhaustive check
        else => unreachable,
    }
}

fn cb_prefixed(cpu: *Cpu, bus: *Peripherals) void {
    const v = @as(Operand, .{ .imm8 = .{} }).read(cpu, bus);
    if (v != null) {
        cpu.ctx.opcode = @intCast(v.? & 0xFF);
        cpu.ctx.cb = true;
        cb_decode(cpu, bus);
    }
}

test "nop decode" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.pc = 0xC000;
    cpu.ctx.opcode = 0x00;
    cpu.decode(&peripherals);
}

const expect = @import("std").testing.expect;
const tutil = @import("test_util.zig");
