//! This file defines the instruction set of CPU.
//! Note that all the instruction consumes at least 1-cycle to fetch the next instruction.

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
    const state = struct {
        var step: usize = 0;
        var cache: u16 = 0;
    };
    while (true) {
        switch (state.step) {
            0 => blk: {
                const v = src.read(cpu, bus);
                if (v != null) {
                    state.step = 1;
                    state.cache = v.?;
                    break :blk;
                }
                return;
            },
            1 => blk: {
                if (dst.write(cpu, bus, state.cache) != null) {
                    state.step = 2;
                    break :blk;
                }
                return;
            },
            2 => {
                state.step = 0;
                cpu.fetch(bus);
                return;
            },
            else => unreachable,
        }
    }
}

/// Compare src with A-register.
/// It subtracts src from A-register, then sets flags according to the result.
pub fn cp(cpu: *Cpu, bus: *Peripherals, src: Operand) void {
    const v = src.read(cpu, bus);
    if (v != null) {
        const u: u8 = @intCast(v.? & 0xFF);
        const res = @subWithOverflow(cpu.regs.a, u);
        cpu.regs.set_zf(res[0] == 0);
        cpu.regs.set_nf(true); // unconditional
        cpu.regs.set_hf((cpu.regs.a & 0x0F) < (u & 0x0F));
        cpu.regs.set_cf(res[1] != 0);

        cpu.fetch(bus);
    }
}

/// Increment a value of an operand, then set flags according to the result if necessary.
pub fn inc(cpu: *Cpu, bus: *Peripherals, src: Operand) void {
    const state = struct {
        var step: usize = 0;
        var cache: u16 = 0;
    };
    while (true) {
        switch (state.step) {
            0 => blk: {
                const v = src.read(cpu, bus);
                if (v != null) {
                    if (src.is8()) {
                        const u: u8 = @intCast(v.? & 0xFF);
                        const res = u +% 1;
                        cpu.regs.set_zf(res == 0);
                        cpu.regs.set_nf(false); // unconditional
                        cpu.regs.set_hf((u & 0x0F) == 0x0F);
                        state.cache = @intCast(res);
                    } else {
                        const u: u16 = v.?;
                        const res = u +% 1;
                        state.cache = res;
                    }

                    state.step = 1;
                    break :blk;
                }
                return;
            },
            1 => {
                if (src.write(cpu, bus, state.cache) != null) {
                    if (src.is8()) {
                        cpu.fetch(bus);
                        state.step = 0;
                    } else {
                        state.step = 2;
                    }
                }
                return;
            },
            2 => {
                state.step = 0;
                cpu.fetch(bus);
                return;
            },
            else => unreachable,
        }
    }
}

/// Decrement a value of an operand, then set flags according to the result if necessary.
pub fn dec(cpu: *Cpu, bus: *Peripherals, src: Operand) void {
    const state = struct {
        var step: usize = 0;
        var cache: u16 = 0;
    };
    while (true) {
        switch (state.step) {
            0 => blk: {
                const v = src.read(cpu, bus);
                if (v != null) {
                    if (src.is8()) {
                        const u: u8 = @intCast(v.? & 0xFF);
                        const res = u -% 1;
                        cpu.regs.set_zf(res == 0);
                        cpu.regs.set_nf(true); // unconditional
                        cpu.regs.set_hf((u & 0x0F) == 0);
                        state.cache = @intCast(res);
                    } else {
                        const u: u16 = v.?;
                        const res = u -% 1;
                        state.cache = res;
                    }

                    state.step = 1;
                    break :blk;
                }
                return;
            },
            1 => {
                if (src.write(cpu, bus, state.cache) != null) {
                    if (src.is8()) {
                        cpu.fetch(bus);
                        state.step = 0;
                    } else {
                        state.step = 2;
                    }
                }
                return;
            },
            2 => {
                state.step = 0;
                cpu.fetch(bus);
                return;
            },
            else => unreachable,
        }
    }
}

/// Bit shift src and append C-flag to the least significant bit.
/// Then set flags according to the result if necessary.
pub fn rl(cpu: *Cpu, bus: *Peripherals, src: Operand) void {
    const state = struct {
        var step: usize = 0;
        var cache: u8 = 0;
    };
    while (true) {
        switch (state.step) {
            0 => blk: {
                const s = src.read(cpu, bus);
                if (s != null) {
                    const u: u8 = @intCast(s.? & 0xFF);
                    const v = (u << 1) | @intFromBool(cpu.regs.cf());
                    cpu.regs.set_zf(v == 0);
                    cpu.regs.set_nf(false); // unconditional
                    cpu.regs.set_hf(false); // unconditional
                    cpu.regs.set_cf((u & 0x80) != 0);
                    state.cache = v;
                    state.step = 1;
                    break :blk;
                }
                return;
            },
            1 => {
                if (src.write(cpu, bus, @intCast(state.cache)) != null) {
                    cpu.fetch(bus);
                    state.step = 0;
                }
                return;
            },
            else => unreachable,
        }
    }
}

/// Check if num-th bit of src is NOT set.
pub fn bit(cpu: *Cpu, bus: *Peripherals, nth: u3, src: Operand) void {
    const s = src.read(cpu, bus);
    if (s != null) {
        const u: u8 = @intCast(s.? & 0xFF);
        cpu.regs.set_zf((u & (@as(u8, 1) << nth)) == 0);
        cpu.regs.set_nf(false); // unconditional
        cpu.regs.set_hf(true); // unconditional

        cpu.fetch(bus);
    }
}

/// Push a 16-bit val to the stack.
/// Note that this instruction consumes additional 1 cycle.
/// Somewhat internal function.
pub fn push16(cpu: *Cpu, bus: *Peripherals, val: u16) ?void {
    const state = struct {
        var step: usize = 0;
        var cache: u8 = 0;
    };

    return switch (state.step) {
        0 => {
            state.step = 1; // consume cycle
            return null;
        },
        1 => {
            const lo: u8 = @intCast(val & 0xFF);
            const hi: u8 = @intCast(val >> 8);
            cpu.regs.sp -%= 1;
            bus.write(cpu.regs.sp, hi);

            state.cache = lo;
            state.step = 2;
            return null;
        },
        2 => {
            cpu.regs.sp -%= 1;
            bus.write(cpu.regs.sp, @intCast(state.cache));

            state.step = 3;
            return null;
        },
        3 => {
            state.step = 0;
            return;
        },
        else => unreachable,
    };
}

/// Push a 16-bit src to the stack.
/// Note that this instruction consumes additional 1 cycle.
/// Consumes 4-cycle in total.
pub fn push(cpu: *Cpu, bus: *Peripherals, src: Operand) void {
    const state = struct {
        var step: usize = 0;
        var cache: u16 = 0;
    };
    while (true) {
        switch (state.step) {
            0 => blk: {
                state.cache = src.read(cpu, bus).?;
                state.step = 1;
                break :blk;
            },
            1 => blk: {
                if (push16(cpu, bus, state.cache) != null) {
                    state.step = 2;
                    break :blk;
                }
                return;
            },
            2 => {
                state.step = 0;
                cpu.fetch(bus);
                return;
            },
            else => unreachable,
        }
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
    try expect(cpu.regs.a == 0x89);
    try expect(cpu.regs.pc == 0xC002);

    // d=Direct8, s=Reg8, 4-cycle, 3-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x23;
    peripherals.write(cpu.regs.pc, 0x20);
    peripherals.write(cpu.regs.pc + 1, 0xC0);
    for (0..4) |_| {
        ld(&cpu, &peripherals, .{ .direct8 = .D }, .{ .reg8 = .A });
    }
    try expect(peripherals.read(0xC020) == 0x23);
    try expect(cpu.regs.pc == 0xC003);

    // d=Reg16, s=Imm16, 3-cycle, 3-PC
    cpu.regs.write_bc(0x0000);
    cpu.regs.pc = 0xC000;
    peripherals.write(cpu.regs.pc, 0x34);
    peripherals.write(cpu.regs.pc + 1, 0x12);
    for (0..3) |_| {
        ld(&cpu, &peripherals, .{ .reg16 = .BC }, .{ .imm16 = .{} });
    }
    try expect(cpu.regs.bc() == 0x1234);
    try expect(cpu.regs.pc == 0xC003);
}

test "cp" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg8, 1-cycle, 1-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.b = 0x12;
    cpu.regs.a = 0x34;
    cp(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);

    try expect(cpu.regs.pc == 0xC001);

    cpu.regs.b = 0x34;
    cpu.regs.a = 0x34;
    cp(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);

    cpu.regs.b = 0x35;
    cpu.regs.a = 0x34;
    cp(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == true);

    cpu.regs.b = 0x40;
    cpu.regs.a = 0x34;
    cp(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == true);

    cpu.regs.b = 0x3F;
    cpu.regs.a = 0x40;
    cp(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == false);

    // src=Indirect, 2-cycle, 2-PC
    cpu.regs.a = 0x12;
    cpu.regs.pc = 0xC000;
    cpu.regs.write_bc(0xC000);
    peripherals.write(cpu.regs.bc(), 0x12);
    for (0..2) |_| {
        cp(&cpu, &peripherals, .{ .indirect = .BC });
    }
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);
}

test "inc" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg8, 1-cycle, 1-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.b = 0x12;
    inc(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.b == 0x13);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);

    cpu.regs.b = 0xFF;
    inc(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.b == 0x00);
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC002);

    // src=Indirect, 3-cycle, 1-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.write_bc(0xC000);
    peripherals.write(cpu.regs.bc(), 0x12);
    inc(&cpu, &peripherals, .{ .indirect = .BC });
    inc(&cpu, &peripherals, .{ .indirect = .BC });
    inc(&cpu, &peripherals, .{ .indirect = .BC });
    try expect(peripherals.read(cpu.regs.bc()) == 0x13);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);

    // src=Reg16, 2-cycle, 1-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.write_bc(0x1234);
    inc(&cpu, &peripherals, .{ .reg16 = .BC });
    inc(&cpu, &peripherals, .{ .reg16 = .BC });
    try expect(cpu.regs.bc() == 0x1235);
    try expect(cpu.regs.pc == 0xC001);
}

test "dec" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg8, 1-cycle, 1-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.b = 0x12;
    dec(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.b == 0x11);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);

    cpu.regs.b = 0x01;
    dec(&cpu, &peripherals, .{ .reg8 = .B });
    try expect(cpu.regs.b == 0x00);
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC002);

    // src=Indirect, 3-cycle, 1-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.write_bc(0xC000);
    peripherals.write(cpu.regs.bc(), 0x10);
    dec(&cpu, &peripherals, .{ .indirect = .BC });
    dec(&cpu, &peripherals, .{ .indirect = .BC });
    dec(&cpu, &peripherals, .{ .indirect = .BC });
    try expect(peripherals.read(cpu.regs.bc()) == 0x0F);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == true);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);
}

test "rl" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg8, 1-cycle (+1 for decode)
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x12;
    cpu.regs.set_cf(true);
    for (0..1) |_| {
        rl(&cpu, &peripherals, .{ .reg8 = .A });
    }
    try expect(cpu.regs.a == 0x25);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);

    // src=Indirect, 3-cycle (+1 for decode)
    cpu.regs.pc = 0xC000;
    cpu.regs.write_bc(0xC000);
    peripherals.write(cpu.regs.bc(), 0x80);
    cpu.regs.set_cf(false);
    for (0..3) |_| {
        rl(&cpu, &peripherals, .{ .indirect = .BC });
    }
    try expect(peripherals.read(cpu.regs.bc()) == 0x00);
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == true);
    try expect(cpu.regs.pc == 0xC001);
}

test "bit" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg8, 1-cycle (+1 for decode)
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x12;
    for (0..1) |_| {
        bit(&cpu, &peripherals, 1, .{ .reg8 = .A });
    }
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);

    // src=Indirect, 2-cycle (+1 for decode)
    cpu.regs.pc = 0xC000;
    cpu.regs.write_bc(0xC000);
    peripherals.write(cpu.regs.bc(), 0x40);
    for (0..2) |_| {
        bit(&cpu, &peripherals, 7, .{ .indirect = .BC });
    }
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);
}

test "push" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg16, 4-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.sp = 0xC100;
    cpu.regs.write_bc(0x1234);
    for (0..4) |_| {
        push(&cpu, &peripherals, .{ .reg16 = .BC });
    }
    try expect(cpu.regs.sp == 0xC100 - 2);
    try expect(peripherals.read(cpu.regs.sp + 0) == 0x34);
    try expect(peripherals.read(cpu.regs.sp + 1) == 0x12);
    try expect(cpu.regs.pc == 0xC001);
}

const expect = @import("std").testing.expect;
const tutil = @import("test_util.zig");
