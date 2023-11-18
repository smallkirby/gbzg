//! This file defines the instruction set of CPU.
//! Note that all the instruction consumes at least 1-cycle to fetch the next instruction.
//!
//! ** Important Notice **
//!
//! Functions in this file uses static local variables to keep the state of the instruction among cycles.
//! These states are shared between all instance of CPU
//! because `fn func(self: @This())` is just a syntax sugar and namespaced,
//! not tied to the instance of the struct.
//! Therefore, if you call these functions before some instruction is finished,
//! the state of the instruction will be overwritten and the instruction will be broken.
//! As a design of this emulator,
//! it is ensured that the instruction finises before other instruction is called
//! including interrupts.
//! You must be carefull when you call these functions in tests.
//! You must finish the instruction before finishing the test case,
//! or other test cases will be broken.

const Cpu = @import("cpu.zig").Cpu;
const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Operand = @import("operand.zig").Operand;
const Cond = @import("operand.zig").Cond;

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
                if (src.read(cpu, bus)) |v| {
                    state.step = 1;
                    state.cache = v;
                    break :blk;
                }
                return;
            },
            1 => blk: {
                if (dst.write(cpu, bus, state.cache)) |_| {
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
    if (src.read(cpu, bus)) |v| {
        const u: u8 = @truncate(v);
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
                if (src.read(cpu, bus)) |v| {
                    if (src.is8()) {
                        const u: u8 = @intCast(v & 0xFF);
                        const res = u +% 1;
                        cpu.regs.set_zf(res == 0);
                        cpu.regs.set_nf(false); // unconditional
                        cpu.regs.set_hf((u & 0x0F) == 0x0F);
                        state.cache = @intCast(res);
                    } else {
                        const u: u16 = v;
                        const res = u +% 1;
                        state.cache = res;
                    }

                    state.step = 1;
                    break :blk;
                }
                return;
            },
            1 => {
                if (src.write(cpu, bus, state.cache)) |_| {
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
                if (src.read(cpu, bus)) |v| {
                    if (src.is8()) {
                        const u: u8 = @truncate(v);
                        const res = u -% 1;
                        cpu.regs.set_zf(res == 0);
                        cpu.regs.set_nf(true); // unconditional
                        cpu.regs.set_hf((u & 0x0F) == 0);
                        state.cache = @intCast(res);
                    } else {
                        const u: u16 = v;
                        const res = u -% 1;
                        state.cache = res;
                    }

                    state.step = 1;
                    break :blk;
                }
                return;
            },
            1 => {
                if (src.write(cpu, bus, state.cache)) |_| {
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
                if (src.read(cpu, bus)) |s| {
                    const u: u8 = @truncate(s);
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
                if (src.write(cpu, bus, @intCast(state.cache))) |_| {
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
    if (src.read(cpu, bus)) |s| {
        const u: u8 = @truncate(s);
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
            const lo: u8 = @truncate(val);
            const hi: u8 = @truncate(val >> 8);
            cpu.regs.sp -%= 1;
            bus.write(&cpu.interrupts, cpu.regs.sp, hi);

            state.cache = lo;
            state.step = 2;
            return null;
        },
        2 => {
            cpu.regs.sp -%= 1;
            bus.write(&cpu.interrupts, cpu.regs.sp, @intCast(state.cache));

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
                if (push16(cpu, bus, state.cache)) |_| {
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

/// Pop a 16-bit value from the stack.
/// Somehwat internal function.
pub fn pop16(cpu: *Cpu, bus: *Peripherals) ?u16 {
    const state = struct {
        var step: usize = 0;
        var cache: u16 = 0;
    };

    switch (state.step) {
        0 => {
            state.cache = bus.read(&cpu.interrupts, cpu.regs.sp);
            cpu.regs.sp +%= 1;
            state.step = 1;
            return null;
        },
        1 => {
            state.cache |= @as(u16, bus.read(&cpu.interrupts, cpu.regs.sp)) << 8;
            cpu.regs.sp +%= 1;
            state.step = 2;
            return null;
        },
        2 => {
            state.step = 0;
            return state.cache;
        },
        else => unreachable,
    }
}

/// Pop a 16-bit value from the stack.
pub fn pop(cpu: *Cpu, bus: *Peripherals, dst: Operand) void {
    if (pop16(cpu, bus)) |v| {
        dst.write(cpu, bus, v).?;
        cpu.fetch(bus);
    }
}

/// Relative jump by Imm8.
pub fn jr(cpu: *Cpu, bus: *Peripherals) void {
    const state = struct {
        var step: usize = 0;
        var cache: u8 = 0;
    };
    switch (state.step) {
        0 => {
            if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |v| {
                const s16 = @as(i16, @as(i8, @bitCast(@as(u8, @truncate(v)))));
                cpu.regs.pc +%= @as(u16, @bitCast(s16));
                state.step = 1;
            }
            return;
        },
        1 => {
            state.step = 0;
            cpu.fetch(bus);
            return;
        },
        else => unreachable,
    }
}

fn cond(cpu: *Cpu, c: Cond) bool {
    return switch (c) {
        .NZ => !cpu.regs.zf(),
        .Z => cpu.regs.zf(),
        .NC => !cpu.regs.cf(),
        .C => cpu.regs.cf(),
    };
}

/// Conditional relative jump by Imm8.
/// Consumes 3-cycle if condition is met, otherwise 2-cycle.
pub fn jrc(cpu: *Cpu, bus: *Peripherals, c: Cond) void {
    const state = struct {
        var step: usize = 0;
        var cache: u8 = 0;
    };
    while (true) {
        switch (state.step) {
            0 => blk: {
                if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |v| {
                    state.step = 1;
                    if (cond(cpu, c)) {
                        const s16 = @as(i16, @as(i8, @bitCast(@as(u8, @truncate(v)))));
                        cpu.regs.pc +%= @as(u16, @bitCast(s16));
                        return;
                    }
                    break :blk;
                }
                return;
            },
            1 => {
                state.step = 0;
                cpu.fetch(bus);
                return;
            },
            else => unreachable,
        }
    }
}

/// Push Imm16 to the stack, then jump to Imm16.
pub fn call(cpu: *Cpu, bus: *Peripherals) void {
    const state = struct {
        var step: usize = 0;
        var cache: u16 = 0;
    };

    while (true) {
        switch (state.step) {
            0 => blk: {
                if (@as(Operand, .{ .imm16 = .{} }).read(cpu, bus)) |v| {
                    state.cache = v;
                    state.step = 1;
                    break :blk;
                }
                return;
            },
            1 => {
                if (push16(cpu, bus, cpu.regs.pc)) |_| {
                    cpu.regs.pc = state.cache;
                    state.step = 0;
                    cpu.fetch(bus);
                }
                return;
            },
            else => unreachable,
        }
    }
}

/// Pop a 16-bit value from the stack, then jump to it.
/// Note that this instruction consumes additional 1 cycle.
pub fn ret(cpu: *Cpu, bus: *Peripherals) void {
    const state = struct {
        var step: usize = 0;
        var cache: u16 = 0;
    };

    switch (state.step) {
        0 => {
            if (pop16(cpu, bus)) |v| {
                cpu.regs.pc = v;
                state.step = 1;
            }
            return;
        },
        1 => {
            state.step = 0;
            cpu.fetch(bus);
            return;
        },
        else => unreachable,
    }
}

/// Enable IME and then ret.
pub fn reti(cpu: *Cpu, bus: *Peripherals) void {
    const state = struct {
        var step: usize = 0;
    };
    switch (state.step) {
        0 => {
            if (pop16(cpu, bus)) |v| {
                cpu.regs.pc = v;
                state.step = 1;
            }
            return;
        },
        1 => {
            cpu.interrupts.ime = true;
            state.step = 0;
            cpu.fetch(bus);
        },
        else => unreachable,
    }
}

/// Enable IME.
pub fn ei(cpu: *Cpu, bus: *Peripherals) void {
    cpu.fetch(bus);
    cpu.interrupts.ime = true;
}

/// Disable IME.
pub fn di(cpu: *Cpu, bus: *Peripherals) void {
    cpu.fetch(bus);
    cpu.interrupts.ime = false;
}

/// Halt CPU until an interrupt is requested.
/// Noth that this instruction is equivalent to `nop` if interrupts are requested on the first cycle.
pub fn halt(cpu: *Cpu, bus: *Peripherals) void {
    const state = struct {
        var step: usize = 0;
    };

    switch (state.step) {
        0 => if (cpu.interrupts.get_interrupt() != 0) {
            cpu.fetch(bus);
        } else {
            state.step = 1;
        },
        1 => if (cpu.interrupts.get_interrupt() != 0) {
            state.step = 0;
            cpu.fetch(bus);
        },
        else => unreachable,
    }
}

/// Add src to A-register, then set flags according to the result.
pub fn add(cpu: *Cpu, bus: *Peripherals, src: Operand) void {
    if (src.read(cpu, bus)) |v| {
        const u: u8 = @truncate(v);
        const res = @addWithOverflow(cpu.regs.a, u);
        cpu.regs.set_zf(res[0] == 0);
        cpu.regs.set_nf(false); // unconditional
        cpu.regs.set_hf((cpu.regs.a & 0x0F) + (u & 0x0F) > 0x0F);
        cpu.regs.set_cf(res[1] != 0);
        cpu.regs.a = res[0];

        cpu.fetch(bus);
    }
}

/// Add src + C-flag to A-register, then set flags according to the result.
pub fn adc(cpu: *Cpu, bus: *Peripherals, src: Operand) void {
    if (src.read(cpu, bus)) |v| {
        const c = @as(u8, @intFromBool(cpu.regs.cf()));
        const u: u8 = @truncate(v);
        const res = cpu.regs.a +% u +% c;
        cpu.regs.set_zf(res == 0);
        cpu.regs.set_nf(false); // unconditional
        cpu.regs.set_hf((cpu.regs.a & 0x0F) + (u & 0x0F) + c > 0x0F);
        cpu.regs.set_cf(res < cpu.regs.a or res < u);
        cpu.regs.a = res;

        cpu.fetch(bus);
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
    peripherals.write(&cpu.interrupts, 0xC000, 0x89);
    ld(&cpu, &peripherals, .{ .reg8 = .A }, .{ .imm8 = .{} });
    ld(&cpu, &peripherals, .{ .reg8 = .A }, .{ .imm8 = .{} });
    try expect(cpu.regs.a == 0x89);
    try expect(cpu.regs.pc == 0xC002);

    // d=Direct8, s=Reg8, 4-cycle, 3-PC
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x23;
    peripherals.write(&cpu.interrupts, cpu.regs.pc, 0x20);
    peripherals.write(&cpu.interrupts, cpu.regs.pc + 1, 0xC0);
    for (0..4) |_| {
        ld(&cpu, &peripherals, .{ .direct8 = .D }, .{ .reg8 = .A });
    }
    try expect(peripherals.read(&cpu.interrupts, 0xC020) == 0x23);
    try expect(cpu.regs.pc == 0xC003);

    // d=Reg16, s=Imm16, 3-cycle, 3-PC
    cpu.regs.write_bc(0x0000);
    cpu.regs.pc = 0xC000;
    peripherals.write(&cpu.interrupts, cpu.regs.pc, 0x34);
    peripherals.write(&cpu.interrupts, cpu.regs.pc + 1, 0x12);
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
    peripherals.write(&cpu.interrupts, cpu.regs.bc(), 0x12);
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
    peripherals.write(&cpu.interrupts, cpu.regs.bc(), 0x12);
    inc(&cpu, &peripherals, .{ .indirect = .BC });
    inc(&cpu, &peripherals, .{ .indirect = .BC });
    inc(&cpu, &peripherals, .{ .indirect = .BC });
    try expect(peripherals.read(&cpu.interrupts, cpu.regs.bc()) == 0x13);
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
    peripherals.write(&cpu.interrupts, cpu.regs.bc(), 0x10);
    dec(&cpu, &peripherals, .{ .indirect = .BC });
    dec(&cpu, &peripherals, .{ .indirect = .BC });
    dec(&cpu, &peripherals, .{ .indirect = .BC });
    try expect(peripherals.read(&cpu.interrupts, cpu.regs.bc()) == 0x0F);
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
    peripherals.write(&cpu.interrupts, cpu.regs.bc(), 0x80);
    cpu.regs.set_cf(false);
    for (0..3) |_| {
        rl(&cpu, &peripherals, .{ .indirect = .BC });
    }
    try expect(peripherals.read(&cpu.interrupts, cpu.regs.bc()) == 0x00);
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
    peripherals.write(&cpu.interrupts, cpu.regs.bc(), 0x40);
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
    try expect(peripherals.read(&cpu.interrupts, cpu.regs.sp + 0) == 0x34);
    try expect(peripherals.read(&cpu.interrupts, cpu.regs.sp + 1) == 0x12);
    try expect(cpu.regs.pc == 0xC001);
}

test "pop" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // dst=Reg16, 3-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.sp = 0xC100;
    peripherals.write(&cpu.interrupts, cpu.regs.sp + 0, 0x34);
    peripherals.write(&cpu.interrupts, cpu.regs.sp + 1, 0x12);
    for (0..3) |_| {
        pop(&cpu, &peripherals, .{ .reg16 = .BC });
    }
    try expect(cpu.regs.sp == 0xC100 + 2);
    try expect(cpu.regs.bc() == 0x1234);
    try expect(cpu.regs.pc == 0xC001);
}

test "jr" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // 3-cycle
    cpu.regs.pc = 0xC000;
    peripherals.write(&cpu.interrupts, cpu.regs.pc, 0x23);
    for (0..3) |_| {
        jr(&cpu, &peripherals);
    }
    try expect(cpu.regs.pc == 0xC025); // +0x23 for jump, +0x01 for Imm8, +0x01 for fetch. Is it right? TODO
}

test "jrc" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // 3-cycle if condition is met
    cpu.regs.pc = 0xC000;
    cpu.regs.set_zf(false);
    peripherals.write(&cpu.interrupts, cpu.regs.pc, 0x23);
    for (0..3) |_| {
        jrc(&cpu, &peripherals, .NZ);
    }
    try expect(cpu.regs.pc == 0xC025); // +0x23 for jump, +0x01 for Imm8, +0x01 for fetch. Is it right? TODO

    // 2-cycle if condition is not met
    cpu.regs.pc = 0xC000;
    cpu.regs.set_zf(false);
    peripherals.write(&cpu.interrupts, cpu.regs.pc, 0x23);
    for (0..2) |_| {
        jrc(&cpu, &peripherals, .Z);
    }
    try expect(cpu.regs.pc == 0xC002); // +0x01 for Imm8, +0x01 for fetch. Is it right? TODO
}

test "call" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // 6-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.sp = 0xC100;
    peripherals.write(&cpu.interrupts, cpu.regs.pc, 0x30);
    peripherals.write(&cpu.interrupts, cpu.regs.pc + 1, 0xC0);
    for (0..6) |_| {
        call(&cpu, &peripherals);
    }
    try expect(cpu.regs.sp == 0xC100 - 2);
    try expect(peripherals.read(&cpu.interrupts, cpu.regs.sp + 0) == 0x02); // +2 for Imm16. Is it right? TODO
    try expect(peripherals.read(&cpu.interrupts, cpu.regs.sp + 1) == 0xC0);
    try expect(cpu.regs.pc == 0xC030 + 1); // +1 for fetch. Is it right? TODO
}

test "ret" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // 4-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.sp = 0xC100;
    peripherals.write(&cpu.interrupts, cpu.regs.sp + 0, 0x30);
    peripherals.write(&cpu.interrupts, cpu.regs.sp + 1, 0xC0);
    for (0..4) |_| {
        ret(&cpu, &peripherals);
    }
    try expect(cpu.regs.sp == 0xC100 + 2);
    try expect(cpu.regs.pc == 0xC030 + 1); // +1 for fetch. Is it right? TODO
}

test "reti" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // 4-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.sp = 0xC100;
    peripherals.write(&cpu.interrupts, cpu.regs.sp + 0, 0x30);
    peripherals.write(&cpu.interrupts, cpu.regs.sp + 1, 0xC0);
    try expect(cpu.interrupts.ime == false);
    for (0..4) |_| {
        reti(&cpu, &peripherals);
    }

    try expect(cpu.regs.sp == 0xC100 + 2);
    try expect(cpu.regs.pc == 0xC030 + 1); // +1 for fetch.
    try expect(cpu.interrupts.ime == true);
}

test "ei/di" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // 1-cycle
    cpu.regs.pc = 0xC000;
    cpu.interrupts.ime = false;
    for (0..1) |_| {
        ei(&cpu, &peripherals);
    }
    try expect(cpu.regs.pc == 0xC001);
    try expect(cpu.interrupts.ime == true);

    // 1-cycle
    cpu.regs.pc = 0xC000;
    for (0..1) |_| {
        di(&cpu, &peripherals);
    }
    try expect(cpu.regs.pc == 0xC001);
    try expect(cpu.interrupts.ime == false);
}

test "halt" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.interrupts.int_enable = 0b0001_1111;
    cpu.interrupts.int_flags = 0b0000_0001;

    // 1-cycle if interrupts are requested
    cpu.regs.pc = 0xC000;
    halt(&cpu, &peripherals);
    try expect(cpu.regs.pc == 0xC001);

    // Halt until interrupts are requested
    cpu.interrupts.int_flags = 0b0000_0000;
    cpu.regs.pc = 0xC000;
    for (0..0x20) |_| {
        halt(&cpu, &peripherals);
    }
    try expect(cpu.regs.pc == 0xC000);

    cpu.interrupts.int_flags = 0b0000_0001;
    halt(&cpu, &peripherals);
    try expect(cpu.regs.pc == 0xC001);
}

test "add" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg8, 1-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x12;
    cpu.regs.b = 0x34;
    for (0..1) |_| {
        add(&cpu, &peripherals, .{ .reg8 = .B });
    }
    try expect(cpu.regs.a == 0x46);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);

    cpu.regs.a = 0x80;
    cpu.regs.b = 0xA3;
    for (0..1) |_| {
        add(&cpu, &peripherals, .{ .reg8 = .B });
    }
    try expect(cpu.regs.a == 0x23);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == true);

    cpu.regs.a = 0xFF;
    cpu.regs.b = 0x01;
    for (0..1) |_| {
        add(&cpu, &peripherals, .{ .reg8 = .B });
    }
    try expect(cpu.regs.a == 0x00);
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == true);

    // src=Imm8, 2-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x12;
    peripherals.write(&cpu.interrupts, cpu.regs.pc, 0x34);
    for (0..2) |_| {
        add(&cpu, &peripherals, .{ .imm8 = .{} });
    }
    try expect(cpu.regs.a == 0x46);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);

    // src=Indirect, 2-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x12;
    cpu.regs.write_bc(0xC000);
    peripherals.write(&cpu.interrupts, cpu.regs.bc(), 0x34);
    for (0..2) |_| {
        add(&cpu, &peripherals, .{ .indirect = .BC });
    }
    try expect(cpu.regs.a == 0x46);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
}

test "adc" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    // src=Reg8, 1-cycle
    cpu.regs.pc = 0xC000;
    cpu.regs.a = 0x12;
    cpu.regs.b = 0x34;
    cpu.regs.set_cf(true);
    for (0..1) |_| {
        adc(&cpu, &peripherals, .{ .reg8 = .B });
    }
    try expect(cpu.regs.a == 0x47);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == false);
    try expect(cpu.regs.pc == 0xC001);

    cpu.regs.a = 0x80;
    cpu.regs.b = 0xA3;
    cpu.regs.set_cf(false);
    for (0..1) |_| {
        adc(&cpu, &peripherals, .{ .reg8 = .B });
    }
    try expect(cpu.regs.a == 0x23);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == false);
    try expect(cpu.regs.cf() == true);

    cpu.regs.a = 0x01;
    cpu.regs.b = 0xFF;
    cpu.regs.set_cf(false);
    for (0..1) |_| {
        adc(&cpu, &peripherals, .{ .reg8 = .B });
    }
    try expect(cpu.regs.a == 0x00);
    try expect(cpu.regs.zf() == true);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == true);

    cpu.regs.a = 0x01;
    cpu.regs.b = 0xFF;
    cpu.regs.set_cf(true);
    for (0..1) |_| {
        adc(&cpu, &peripherals, .{ .reg8 = .B });
    }
    try expect(cpu.regs.a == 0x01);
    try expect(cpu.regs.zf() == false);
    try expect(cpu.regs.nf() == false);
    try expect(cpu.regs.hf() == true);
    try expect(cpu.regs.cf() == true);
}

const expect = @import("std").testing.expect;
const tutil = @import("test_util.zig");
