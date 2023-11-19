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
        0x10 => inst.stop(cpu, bus),
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
        0x07 => inst.rlca(cpu, bus),
        0x17 => inst.rla(cpu, bus),
        0x27 => inst.daa(cpu, bus),
        0x37 => inst.scf(cpu, bus),
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
        0x0F => inst.rrca(cpu, bus),
        0x1F => inst.rra(cpu, bus),
        0x2F => inst.cpl(cpu, bus),
        0x3F => inst.ccf(cpu, bus),
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
        0x80 => inst.add(cpu, bus, .{ .reg8 = .B }),
        0x90 => inst.sub(cpu, bus, .{ .reg8 = .B }),
        0xA0 => inst.and_(cpu, bus, .{ .reg8 = .B }),
        0xB0 => inst.or_(cpu, bus, .{ .reg8 = .B }),
        0x81 => inst.add(cpu, bus, .{ .reg8 = .C }),
        0x91 => inst.sub(cpu, bus, .{ .reg8 = .C }),
        0xA1 => inst.and_(cpu, bus, .{ .reg8 = .C }),
        0xB1 => inst.or_(cpu, bus, .{ .reg8 = .C }),
        0x82 => inst.add(cpu, bus, .{ .reg8 = .D }),
        0x92 => inst.sub(cpu, bus, .{ .reg8 = .D }),
        0xA2 => inst.and_(cpu, bus, .{ .reg8 = .D }),
        0xB2 => inst.or_(cpu, bus, .{ .reg8 = .D }),
        0x83 => inst.add(cpu, bus, .{ .reg8 = .E }),
        0x93 => inst.sub(cpu, bus, .{ .reg8 = .E }),
        0xA3 => inst.and_(cpu, bus, .{ .reg8 = .E }),
        0xB3 => inst.or_(cpu, bus, .{ .reg8 = .E }),
        0x84 => inst.add(cpu, bus, .{ .reg8 = .H }),
        0x94 => inst.sub(cpu, bus, .{ .reg8 = .H }),
        0xA4 => inst.and_(cpu, bus, .{ .reg8 = .H }),
        0xB4 => inst.or_(cpu, bus, .{ .reg8 = .H }),
        0x85 => inst.add(cpu, bus, .{ .reg8 = .L }),
        0x95 => inst.sub(cpu, bus, .{ .reg8 = .L }),
        0xA5 => inst.and_(cpu, bus, .{ .reg8 = .L }),
        0xB5 => inst.or_(cpu, bus, .{ .reg8 = .L }),
        0x86 => inst.add(cpu, bus, .{ .indirect = .HL }),
        0x96 => inst.sub(cpu, bus, .{ .indirect = .HL }),
        0xA6 => inst.and_(cpu, bus, .{ .indirect = .HL }),
        0xB6 => inst.or_(cpu, bus, .{ .indirect = .HL }),
        0x87 => inst.add(cpu, bus, .{ .reg8 = .A }),
        0x97 => inst.sub(cpu, bus, .{ .reg8 = .A }),
        0xA7 => inst.and_(cpu, bus, .{ .reg8 = .A }),
        0xB7 => inst.or_(cpu, bus, .{ .reg8 = .A }),
        0x88 => inst.adc(cpu, bus, .{ .reg8 = .B }),
        0x98 => inst.sbc(cpu, bus, .{ .reg8 = .B }),
        0xA8 => inst.xor(cpu, bus, .{ .reg8 = .B }),
        0xB8 => unreachable,
        0x89 => inst.adc(cpu, bus, .{ .reg8 = .C }),
        0x99 => inst.sbc(cpu, bus, .{ .reg8 = .C }),
        0xA9 => inst.xor(cpu, bus, .{ .reg8 = .C }),
        0xB9 => unreachable,
        0x8A => inst.adc(cpu, bus, .{ .reg8 = .D }),
        0x9A => inst.sbc(cpu, bus, .{ .reg8 = .D }),
        0xAA => inst.xor(cpu, bus, .{ .reg8 = .D }),
        0xBA => unreachable,
        0x8B => inst.adc(cpu, bus, .{ .reg8 = .E }),
        0x9B => inst.sbc(cpu, bus, .{ .reg8 = .E }),
        0xAB => inst.xor(cpu, bus, .{ .reg8 = .E }),
        0xBB => unreachable,
        0x8C => inst.adc(cpu, bus, .{ .reg8 = .H }),
        0x9C => inst.sbc(cpu, bus, .{ .reg8 = .H }),
        0xAC => inst.xor(cpu, bus, .{ .reg8 = .H }),
        0xBC => unreachable,
        0x8D => inst.adc(cpu, bus, .{ .reg8 = .L }),
        0x9D => inst.sbc(cpu, bus, .{ .reg8 = .L }),
        0xAD => inst.xor(cpu, bus, .{ .reg8 = .L }),
        0xBD => unreachable,
        0x8E => inst.adc(cpu, bus, .{ .indirect = .HL }),
        0x9E => inst.sbc(cpu, bus, .{ .indirect = .HL }),
        0xAE => inst.xor(cpu, bus, .{ .indirect = .HL }),
        0xBE => unreachable,
        0x8F => inst.adc(cpu, bus, .{ .reg8 = .A }),
        0x9F => inst.sbc(cpu, bus, .{ .reg8 = .A }),
        0xAF => inst.xor(cpu, bus, .{ .reg8 = .A }),
        0xBF => inst.cp(cpu, bus, .{ .reg8 = .A }),
        0xC0 => inst.retc(cpu, bus, .NZ),
        0xD0 => inst.retc(cpu, bus, .NC),
        0xE0 => inst.ld(cpu, bus, .{ .direct8 = .DFF }, .{ .reg8 = .A }),
        0xF0 => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .direct8 = .DFF }),
        0xC1 => inst.pop(cpu, bus, .{ .reg16 = .BC }),
        0xD1 => inst.pop(cpu, bus, .{ .reg16 = .DE }),
        0xE1 => inst.pop(cpu, bus, .{ .reg16 = .HL }),
        0xF1 => inst.pop(cpu, bus, .{ .reg16 = .AF }),
        0xC2 => inst.jpc(cpu, bus, .NZ),
        0xD2 => inst.jpc(cpu, bus, .NC),
        0xE2 => inst.ld(cpu, bus, .{ .indirect = .CFF }, .{ .reg8 = .A }),
        0xF2 => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .indirect = .CFF }),
        0xC3 => inst.jp(cpu, bus),
        0xD3, 0xE3 => unreachable,
        0xF3 => inst.di(cpu, bus),
        0xC4 => inst.callc(cpu, bus, .NZ),
        0xD4 => inst.callc(cpu, bus, .NC),
        0xE4 => unreachable,
        0xF4 => unreachable,
        0xC5 => inst.push(cpu, bus, .{ .reg16 = .BC }),
        0xD5 => inst.push(cpu, bus, .{ .reg16 = .DE }),
        0xE5 => inst.push(cpu, bus, .{ .reg16 = .HL }),
        0xF5 => inst.push(cpu, bus, .{ .reg16 = .AF }),
        0xC6 => inst.add(cpu, bus, .{ .imm8 = .{} }),
        0xD6 => inst.sub(cpu, bus, .{ .imm8 = .{} }),
        0xE6 => inst.and_(cpu, bus, .{ .imm8 = .{} }),
        0xF6 => inst.or_(cpu, bus, .{ .imm8 = .{} }),
        0xC7 => inst.rst(cpu, bus, 0x00),
        0xD7 => inst.rst(cpu, bus, 0x10),
        0xE7 => inst.rst(cpu, bus, 0x20),
        0xF7 => inst.rst(cpu, bus, 0x30),
        0xC8 => inst.retc(cpu, bus, .Z),
        0xD8 => inst.retc(cpu, bus, .C),
        0xE8, 0xF8 => unreachable,
        0xC9 => inst.ret(cpu, bus),
        0xD9 => inst.reti(cpu, bus),
        0xE9 => inst.jphl(cpu, bus),
        0xF9 => inst.ld_sphl(Cpu, bus),
        0xCA => inst.jpc(cpu, bus, .Z),
        0xDA => inst.jpc(cpu, bus, .C),
        0xEA => inst.ld(cpu, bus, .{ .direct8 = .D }, .{ .reg8 = .A }),
        0xFA => inst.ld(cpu, bus, .{ .reg8 = .A }, .{ .direct8 = .D }),
        0xCB => cb_prefixed(cpu, bus),
        0xDB, 0xEB => unreachable,
        0xFB => inst.ei(cpu, bus),
        0xCC => inst.callc(cpu, bus, .Z),
        0xDC => inst.callc(cpu, bus, .C),
        0xEC, 0xFC => unreachable,
        0xCD => inst.call(cpu, bus),
        0xDD, 0xED, 0xFD => unreachable,
        0xCE => inst.adc(cpu, bus, .{ .imm8 = .{} }),
        0xDE => inst.sbc(cpu, bus, .{ .imm8 = .{} }),
        0xEE => inst.xor(cpu, bus, .{ .imm8 = .{} }),
        0xFE => inst.cp(cpu, bus, .{ .imm8 = .{} }),
        0xCF => inst.rst(cpu, bus, 0x08),
        0xDF => inst.rst(cpu, bus, 0x18),
        0xEF => inst.rst(cpu, bus, 0x28),
        0xFF => inst.rst(cpu, bus, 0x38),
    }
}

/// Decode the current CB-prefixed opcode and execute the instruction.
pub fn cb_decode(cpu: *Cpu, bus: *Peripherals) void {
    switch (cpu.ctx.opcode) {
        0x00 => inst.rlc(cpu, bus, .{ .reg8 = .B }),
        0x10 => inst.rl(cpu, bus, .{ .reg8 = .B }),
        0x20 => inst.sla(cpu, bus, .{ .reg8 = .B }),
        0x30 => inst.swap(cpu, bus, .{ .reg8 = .B }),
        0x01 => inst.rlc(cpu, bus, .{ .reg8 = .C }),
        0x11 => inst.rl(cpu, bus, .{ .reg8 = .C }),
        0x21 => inst.sla(cpu, bus, .{ .reg8 = .C }),
        0x31 => inst.swap(cpu, bus, .{ .reg8 = .C }),
        0x02 => inst.rlc(cpu, bus, .{ .reg8 = .D }),
        0x12 => inst.rl(cpu, bus, .{ .reg8 = .D }),
        0x22 => inst.sla(cpu, bus, .{ .reg8 = .D }),
        0x32 => inst.swap(cpu, bus, .{ .reg8 = .D }),
        0x03 => inst.rlc(cpu, bus, .{ .reg8 = .E }),
        0x13 => inst.rl(cpu, bus, .{ .reg8 = .E }),
        0x23 => inst.sla(cpu, bus, .{ .reg8 = .E }),
        0x33 => inst.swap(cpu, bus, .{ .reg8 = .E }),
        0x04 => inst.rlc(cpu, bus, .{ .reg8 = .H }),
        0x14 => inst.rl(cpu, bus, .{ .reg8 = .H }),
        0x24 => inst.sla(cpu, bus, .{ .reg8 = .H }),
        0x34 => inst.swap(cpu, bus, .{ .reg8 = .H }),
        0x05 => inst.rlc(cpu, bus, .{ .reg8 = .L }),
        0x15 => inst.rl(cpu, bus, .{ .reg8 = .L }),
        0x25 => inst.sla(cpu, bus, .{ .reg8 = .L }),
        0x35 => inst.swap(cpu, bus, .{ .reg8 = .L }),
        0x06 => inst.rlc(cpu, bus, .{ .indirect = .HL }),
        0x16 => inst.rl(cpu, bus, .{ .indirect = .HL }),
        0x26 => inst.sla(cpu, bus, .{ .indirect = .HL }),
        0x36 => inst.swap(cpu, bus, .{ .indirect = .HL }),
        0x07 => inst.rlc(cpu, bus, .{ .reg8 = .A }),
        0x17 => inst.rl(cpu, bus, .{ .reg8 = .A }),
        0x27 => inst.sla(cpu, bus, .{ .reg8 = .A }),
        0x37 => inst.swap(cpu, bus, .{ .reg8 = .A }),
        0x08 => inst.rrc(cpu, bus, .{ .reg8 = .B }),
        0x18 => inst.rr(cpu, bus, .{ .reg8 = .B }),
        0x28 => inst.sra(cpu, bus, .{ .reg8 = .B }),
        0x38 => inst.srl(cpu, bus, .{ .reg8 = .B }),
        0x09 => inst.rrc(cpu, bus, .{ .reg8 = .C }),
        0x19 => inst.rr(cpu, bus, .{ .reg8 = .C }),
        0x29 => inst.sra(cpu, bus, .{ .reg8 = .C }),
        0x39 => inst.srl(cpu, bus, .{ .reg8 = .C }),
        0x0A => inst.rrc(cpu, bus, .{ .reg8 = .D }),
        0x1A => inst.rr(cpu, bus, .{ .reg8 = .D }),
        0x2A => inst.sra(cpu, bus, .{ .reg8 = .D }),
        0x3A => inst.srl(cpu, bus, .{ .reg8 = .D }),
        0x0B => inst.rrc(cpu, bus, .{ .reg8 = .E }),
        0x1B => inst.rr(cpu, bus, .{ .reg8 = .E }),
        0x2B => inst.sra(cpu, bus, .{ .reg8 = .E }),
        0x3B => inst.srl(cpu, bus, .{ .reg8 = .E }),
        0x0C => inst.rrc(cpu, bus, .{ .reg8 = .H }),
        0x1C => inst.rr(cpu, bus, .{ .reg8 = .H }),
        0x2C => inst.sra(cpu, bus, .{ .reg8 = .H }),
        0x3C => inst.srl(cpu, bus, .{ .reg8 = .H }),
        0x0D => inst.rrc(cpu, bus, .{ .reg8 = .L }),
        0x1D => inst.rr(cpu, bus, .{ .reg8 = .L }),
        0x2D => inst.sra(cpu, bus, .{ .reg8 = .L }),
        0x3D => inst.srl(cpu, bus, .{ .reg8 = .L }),
        0x0E => inst.rrc(cpu, bus, .{ .indirect = .HL }),
        0x1E => inst.rr(cpu, bus, .{ .indirect = .HL }),
        0x2E => inst.sra(cpu, bus, .{ .indirect = .HL }),
        0x3E => inst.srl(cpu, bus, .{ .indirect = .HL }),
        0x0F => inst.rrc(cpu, bus, .{ .reg8 = .A }),
        0x1F => inst.rr(cpu, bus, .{ .reg8 = .A }),
        0x2F => inst.sra(cpu, bus, .{ .reg8 = .A }),
        0x3F => inst.srl(cpu, bus, .{ .reg8 = .A }),
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
        0x80 => inst.res_(cpu, bus, 0, .{ .reg8 = .B }),
        0x90 => inst.res_(cpu, bus, 2, .{ .reg8 = .B }),
        0xA0 => inst.res_(cpu, bus, 4, .{ .reg8 = .B }),
        0xB0 => inst.res_(cpu, bus, 6, .{ .reg8 = .B }),
        0x81 => inst.res_(cpu, bus, 0, .{ .reg8 = .C }),
        0x91 => inst.res_(cpu, bus, 2, .{ .reg8 = .C }),
        0xA1 => inst.res_(cpu, bus, 4, .{ .reg8 = .C }),
        0xB1 => inst.res_(cpu, bus, 6, .{ .reg8 = .C }),
        0x82 => inst.res_(cpu, bus, 0, .{ .reg8 = .D }),
        0x92 => inst.res_(cpu, bus, 2, .{ .reg8 = .D }),
        0xA2 => inst.res_(cpu, bus, 4, .{ .reg8 = .D }),
        0xB2 => inst.res_(cpu, bus, 6, .{ .reg8 = .D }),
        0x83 => inst.res_(cpu, bus, 0, .{ .reg8 = .E }),
        0x93 => inst.res_(cpu, bus, 2, .{ .reg8 = .E }),
        0xA3 => inst.res_(cpu, bus, 4, .{ .reg8 = .E }),
        0xB3 => inst.res_(cpu, bus, 6, .{ .reg8 = .E }),
        0x84 => inst.res_(cpu, bus, 0, .{ .reg8 = .H }),
        0x94 => inst.res_(cpu, bus, 2, .{ .reg8 = .H }),
        0xA4 => inst.res_(cpu, bus, 4, .{ .reg8 = .H }),
        0xB4 => inst.res_(cpu, bus, 6, .{ .reg8 = .H }),
        0x85 => inst.res_(cpu, bus, 0, .{ .reg8 = .L }),
        0x95 => inst.res_(cpu, bus, 2, .{ .reg8 = .L }),
        0xA5 => inst.res_(cpu, bus, 4, .{ .reg8 = .L }),
        0xB5 => inst.res_(cpu, bus, 6, .{ .reg8 = .L }),
        0x86 => inst.res_(cpu, bus, 0, .{ .indirect = .HL }),
        0x96 => inst.res_(cpu, bus, 2, .{ .indirect = .HL }),
        0xA6 => inst.res_(cpu, bus, 4, .{ .indirect = .HL }),
        0xB6 => inst.res_(cpu, bus, 6, .{ .indirect = .HL }),
        0x87 => inst.res_(cpu, bus, 0, .{ .reg8 = .A }),
        0x97 => inst.res_(cpu, bus, 2, .{ .reg8 = .A }),
        0xA7 => inst.res_(cpu, bus, 4, .{ .reg8 = .A }),
        0xB7 => inst.res_(cpu, bus, 6, .{ .reg8 = .A }),
        0x88 => inst.res_(cpu, bus, 1, .{ .reg8 = .B }),
        0x98 => inst.res_(cpu, bus, 3, .{ .reg8 = .B }),
        0xA8 => inst.res_(cpu, bus, 5, .{ .reg8 = .B }),
        0xB8 => inst.res_(cpu, bus, 7, .{ .reg8 = .B }),
        0x89 => inst.res_(cpu, bus, 1, .{ .reg8 = .C }),
        0x99 => inst.res_(cpu, bus, 3, .{ .reg8 = .C }),
        0xA9 => inst.res_(cpu, bus, 5, .{ .reg8 = .C }),
        0xB9 => inst.res_(cpu, bus, 7, .{ .reg8 = .C }),
        0x8A => inst.res_(cpu, bus, 1, .{ .reg8 = .D }),
        0x9A => inst.res_(cpu, bus, 3, .{ .reg8 = .D }),
        0xAA => inst.res_(cpu, bus, 5, .{ .reg8 = .D }),
        0xBA => inst.res_(cpu, bus, 7, .{ .reg8 = .D }),
        0x8B => inst.res_(cpu, bus, 1, .{ .reg8 = .E }),
        0x9B => inst.res_(cpu, bus, 3, .{ .reg8 = .E }),
        0xAB => inst.res_(cpu, bus, 5, .{ .reg8 = .E }),
        0xBB => inst.res_(cpu, bus, 7, .{ .reg8 = .E }),
        0x8C => inst.res_(cpu, bus, 1, .{ .reg8 = .H }),
        0x9C => inst.res_(cpu, bus, 3, .{ .reg8 = .H }),
        0xAC => inst.res_(cpu, bus, 5, .{ .reg8 = .H }),
        0xBC => inst.res_(cpu, bus, 7, .{ .reg8 = .H }),
        0x8D => inst.res_(cpu, bus, 1, .{ .reg8 = .L }),
        0x9D => inst.res_(cpu, bus, 3, .{ .reg8 = .L }),
        0xAD => inst.res_(cpu, bus, 5, .{ .reg8 = .L }),
        0xBD => inst.res_(cpu, bus, 7, .{ .reg8 = .L }),
        0x8E => inst.res_(cpu, bus, 1, .{ .indirect = .HL }),
        0x9E => inst.res_(cpu, bus, 3, .{ .indirect = .HL }),
        0xAE => inst.res_(cpu, bus, 5, .{ .indirect = .HL }),
        0xBE => inst.res_(cpu, bus, 7, .{ .indirect = .HL }),
        0x8F => inst.res_(cpu, bus, 1, .{ .reg8 = .A }),
        0x9F => inst.res_(cpu, bus, 3, .{ .reg8 = .A }),
        0xAF => inst.res_(cpu, bus, 5, .{ .reg8 = .A }),
        0xBF => inst.res_(cpu, bus, 7, .{ .reg8 = .A }),
        0xC0 => inst.set(cpu, bus, 0, .{ .reg8 = .B }),
        0xD0 => inst.set(cpu, bus, 2, .{ .reg8 = .B }),
        0xE0 => inst.set(cpu, bus, 4, .{ .reg8 = .B }),
        0xF0 => inst.set(cpu, bus, 6, .{ .reg8 = .B }),
        0xC1 => inst.set(cpu, bus, 0, .{ .reg8 = .C }),
        0xD1 => inst.set(cpu, bus, 2, .{ .reg8 = .C }),
        0xE1 => inst.set(cpu, bus, 4, .{ .reg8 = .C }),
        0xF1 => inst.set(cpu, bus, 6, .{ .reg8 = .C }),
        0xC2 => inst.set(cpu, bus, 0, .{ .reg8 = .D }),
        0xD2 => inst.set(cpu, bus, 2, .{ .reg8 = .D }),
        0xE2 => inst.set(cpu, bus, 4, .{ .reg8 = .D }),
        0xF2 => inst.set(cpu, bus, 6, .{ .reg8 = .D }),
        0xC3 => inst.set(cpu, bus, 0, .{ .reg8 = .E }),
        0xD3 => inst.set(cpu, bus, 2, .{ .reg8 = .E }),
        0xE3 => inst.set(cpu, bus, 4, .{ .reg8 = .E }),
        0xF3 => inst.set(cpu, bus, 6, .{ .reg8 = .E }),
        0xC4 => inst.set(cpu, bus, 0, .{ .reg8 = .H }),
        0xD4 => inst.set(cpu, bus, 2, .{ .reg8 = .H }),
        0xE4 => inst.set(cpu, bus, 4, .{ .reg8 = .H }),
        0xF4 => inst.set(cpu, bus, 6, .{ .reg8 = .H }),
        0xC5 => inst.set(cpu, bus, 0, .{ .reg8 = .L }),
        0xD5 => inst.set(cpu, bus, 2, .{ .reg8 = .L }),
        0xE5 => inst.set(cpu, bus, 4, .{ .reg8 = .L }),
        0xF5 => inst.set(cpu, bus, 6, .{ .reg8 = .L }),
        0xC6 => inst.set(cpu, bus, 0, .{ .indirect = .HL }),
        0xD6 => inst.set(cpu, bus, 2, .{ .indirect = .HL }),
        0xE6 => inst.set(cpu, bus, 4, .{ .indirect = .HL }),
        0xF6 => inst.set(cpu, bus, 6, .{ .indirect = .HL }),
        0xC7 => inst.set(cpu, bus, 0, .{ .reg8 = .A }),
        0xD7 => inst.set(cpu, bus, 2, .{ .reg8 = .A }),
        0xE7 => inst.set(cpu, bus, 4, .{ .reg8 = .A }),
        0xF7 => inst.set(cpu, bus, 6, .{ .reg8 = .A }),
        0xC8 => inst.set(cpu, bus, 1, .{ .reg8 = .B }),
        0xD8 => inst.set(cpu, bus, 3, .{ .reg8 = .B }),
        0xE8 => inst.set(cpu, bus, 5, .{ .reg8 = .B }),
        0xF8 => inst.set(cpu, bus, 7, .{ .reg8 = .B }),
        0xC9 => inst.set(cpu, bus, 1, .{ .reg8 = .C }),
        0xD9 => inst.set(cpu, bus, 3, .{ .reg8 = .C }),
        0xE9 => inst.set(cpu, bus, 5, .{ .reg8 = .C }),
        0xF9 => inst.set(cpu, bus, 7, .{ .reg8 = .C }),
        0xCA => inst.set(cpu, bus, 1, .{ .reg8 = .D }),
        0xDA => inst.set(cpu, bus, 3, .{ .reg8 = .D }),
        0xEA => inst.set(cpu, bus, 5, .{ .reg8 = .D }),
        0xFA => inst.set(cpu, bus, 7, .{ .reg8 = .D }),
        0xCB => inst.set(cpu, bus, 1, .{ .reg8 = .E }),
        0xDB => inst.set(cpu, bus, 3, .{ .reg8 = .E }),
        0xEB => inst.set(cpu, bus, 5, .{ .reg8 = .E }),
        0xFB => inst.set(cpu, bus, 7, .{ .reg8 = .E }),
        0xCC => inst.set(cpu, bus, 1, .{ .reg8 = .H }),
        0xDC => inst.set(cpu, bus, 3, .{ .reg8 = .H }),
        0xEC => inst.set(cpu, bus, 5, .{ .reg8 = .H }),
        0xFC => inst.set(cpu, bus, 7, .{ .reg8 = .H }),
        0xCD => inst.set(cpu, bus, 1, .{ .reg8 = .L }),
        0xDD => inst.set(cpu, bus, 3, .{ .reg8 = .L }),
        0xED => inst.set(cpu, bus, 5, .{ .reg8 = .L }),
        0xFD => inst.set(cpu, bus, 7, .{ .reg8 = .L }),
        0xCE => inst.set(cpu, bus, 1, .{ .indirect = .HL }),
        0xDE => inst.set(cpu, bus, 3, .{ .indirect = .HL }),
        0xEE => inst.set(cpu, bus, 5, .{ .indirect = .HL }),
        0xFE => inst.set(cpu, bus, 7, .{ .indirect = .HL }),
        0xCF => inst.set(cpu, bus, 1, .{ .reg8 = .A }),
        0xDF => inst.set(cpu, bus, 3, .{ .reg8 = .A }),
        0xEF => inst.set(cpu, bus, 5, .{ .reg8 = .A }),
        0xFF => inst.set(cpu, bus, 7, .{ .reg8 = .A }),
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
