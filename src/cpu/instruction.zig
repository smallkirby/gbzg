//! This file defines the instruction set of CPU.

const Cpu = @import("cpu.zig").Cpu;
const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Operand = @import("operand.zig").Operand;

/// Do nothing. Just fetch the next instruction.
pub fn nop(cpu: *Cpu, bus: *Peripherals) void {
    cpu.fetch(bus);
}

/// Load or move a value from a source to a destination.
pub fn ld(cpu: *Cpu, bus: *Peripherals, dst: Operand, src: Operand) void {
    switch (cpu.ctx.inst_ctx.step orelse 0) {
        0 => {
            const v = src.read(cpu, bus);
            if (v != null) {
                cpu.ctx.inst_ctx.step = 1;
                cpu.ctx.inst_ctx.cache = v.?;
            }
        },
        1 => {
            if (dst.write(cpu, bus, cpu.ctx.inst_ctx.cache.?) != null) {
                cpu.ctx.inst_ctx.step = 2;
            }
        },
        2 => {
            cpu.ctx.inst_ctx.step = null;
            cpu.fetch(bus);
        },
        else => unreachable,
    }
}

test "nop" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    const pc = cpu.regs.pc;
    nop(&cpu, &peripherals);
    try expect(cpu.regs.pc == pc + 1);
}

test "ld" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // d=Reg8, s=Imm8, 2-cycle, 2-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x00;
    peripherals.write(0xC000, 0x89);
    ld(&cpu, &peripherals, .{ .reg8 = .A }, .{ .imm8 = .{} });
    ld(&cpu, &peripherals, .{ .reg8 = .A }, .{ .imm8 = .{} });
    try expect(cpu.regs.a != 0x89);
    ld(&cpu, &peripherals, .{ .reg8 = .A }, .{ .imm8 = .{} });
    try expect(cpu.regs.a == 0x89);
    ld(&cpu, &peripherals, .{ .reg8 = .A }, .{ .imm8 = .{} });
    try expect(cpu.regs.pc == 0xC002);

    // d=Direct8, s=Reg8, 4-cycle, 3-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x23;
    peripherals.write(cpu.regs.pc, 0x20);
    peripherals.write(cpu.regs.pc + 1, 0xC0);
    for (0..5) |_| {
        ld(&cpu, &peripherals, .{ .direct8 = .D }, .{ .reg8 = .A });
    }
    try expect(peripherals.read(0xC020) == 0x23);
    try expect(cpu.regs.pc == 0xC002);
    ld(&cpu, &peripherals, .{ .direct8 = .D }, .{ .reg8 = .A });
    try expect(cpu.regs.pc == 0xC003);

    // d=Reg16, s=Imm16, 3-cycle, 3-PC
    cpu.regs.write_bc(0x0000);
    cpu.regs.pc = 0xC000;
    peripherals.write(cpu.regs.pc, 0x34);
    peripherals.write(cpu.regs.pc + 1, 0x12);
    for (0..4) |_| {
        ld(&cpu, &peripherals, .{ .reg16 = .BC }, .{ .imm16 = .{} });
    }
    try expect(cpu.regs.bc() == 0x1234);
    try expect(cpu.regs.pc == 0xC002);
    ld(&cpu, &peripherals, .{ .reg16 = .BC }, .{ .imm16 = .{} });
    try expect(cpu.regs.pc == 0xC003);
}

const expect = @import("std").testing.expect;
const tutil = @import("test_util.zig");
