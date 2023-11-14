//! This file defines available operands of instructions.
//! Memory access consumes M-cycles.
//! If the IO does not complete in a 1 M-cycle, IO function returns null.

const Peripherals = @import("../peripherals.zig").Peripherals;
const Cpu = @import("cpu.zig").Cpu;

fn intNullCastU16(x: ?u8) ?u16 {
    return if (x == null) null else @intCast(x.?);
}

/// Available operands of instructions
pub const Operand = union(enum) {
    reg8: Reg8,
    imm8: Imm8,
    indirect: Indirect,
    direct8: Direct8,

    reg16: Reg16,
    imm16: Imm16,
    direct16: Direct16,

    pub fn read(self: @This(), cpu: *Cpu, peripherals: *Peripherals) ?u16 {
        return switch (self) {
            .reg8 => intNullCastU16(self.reg8.read(cpu, peripherals)),
            .imm8 => intNullCastU16(Imm8.read(cpu, peripherals)),
            .indirect => intNullCastU16(self.indirect.read(cpu, peripherals)),
            .direct8 => intNullCastU16(self.direct8.read(cpu, peripherals)),

            .reg16 => self.reg16.read(cpu, peripherals),
            .imm16 => Imm16.read(cpu, peripherals),
            .direct16 => Direct16.read(cpu, peripherals),
        };
    }

    pub fn write(self: @This(), cpu: *Cpu, peripherals: *Peripherals, val: u16) ?void {
        const val8: u8 = @intCast(val & 0xFF);
        return switch (self) {
            .reg8 => self.reg8.write(cpu, peripherals, val8),
            .imm8 => Imm8.write(cpu, peripherals, val8),
            .indirect => self.indirect.write(cpu, peripherals, val8),
            .direct8 => self.direct8.write(cpu, peripherals, val8),

            .reg16 => self.reg16.write(cpu, peripherals, val),
            .imm16 => Imm16.write(cpu, peripherals, val),
            .direct16 => Direct16.write(cpu, peripherals, val),
        };
    }

    pub fn is8(self: @This()) bool {
        return switch (self) {
            .reg8, .imm8, .indirect, .direct8 => true,
            .reg16, .imm16, .direct16 => false,
        };
    }

    pub fn is16(self: @This()) bool {
        return switch (self) {
            .reg8, .imm8, .indirect, .direct8 => false,
            .reg16, .imm16, .direct16 => true,
        };
    }
};

/// 8-bit register operands
pub const Reg8 = enum(u8) {
    A,
    B,
    C,
    D,
    E,
    H,
    L,

    /// Read 8-bit value from a register.
    /// Consumes 0 cycles.
    pub fn read(self: @This(), cpu: *Cpu, _: *Peripherals) ?u8 {
        return switch (self) {
            .A => cpu.regs.a,
            .B => cpu.regs.b,
            .C => cpu.regs.c,
            .D => cpu.regs.d,
            .E => cpu.regs.e,
            .H => cpu.regs.h,
            .L => cpu.regs.l,
        };
    }

    /// Write 8-bit value to a register.
    /// Consumes 0 cycles.
    pub fn write(self: @This(), cpu: *Cpu, _: *Peripherals, val: u8) void {
        switch (self) {
            .A => cpu.regs.a = val,
            .B => cpu.regs.b = val,
            .C => cpu.regs.c = val,
            .D => cpu.regs.d = val,
            .E => cpu.regs.e = val,
            .H => cpu.regs.h = val,
            .L => cpu.regs.l = val,
        }
    }
};

/// 16-bit register operands
pub const Reg16 = enum(u8) {
    AF,
    BC,
    DE,
    HL,
    SP,

    /// Read 16-bit value from register pair.
    /// Consumes 0 cycles.
    pub fn read(self: @This(), cpu: *Cpu, _: *Peripherals) ?u16 {
        return switch (self) {
            .AF => cpu.regs.af(),
            .BC => cpu.regs.bc(),
            .DE => cpu.regs.de(),
            .HL => cpu.regs.hl(),
            .SP => cpu.regs.sp,
        };
    }

    /// Write 16-bit value to register pair
    /// Consumes 0 cycles.
    pub fn write(self: @This(), cpu: *Cpu, _: *Peripherals, val: u16) void {
        switch (self) {
            .AF => cpu.regs.write_af(val),
            .BC => cpu.regs.write_bc(val),
            .DE => cpu.regs.write_de(val),
            .HL => cpu.regs.write_hl(val),
            .SP => cpu.regs.sp = val,
        }
    }
};

/// 8-bit immediate value pointed by PC
pub const Imm8 = struct {
    /// Read 8-bit value from memory pointed by PC.
    /// Consumes 1 cycle.
    /// Increments PC by 1.
    pub fn read(cpu: *Cpu, bus: *Peripherals) ?u8 {
        const state = struct {
            var step: usize = 0;
            var cache: u8 = 0;
        };
        return switch (state.step) {
            0 => blk: {
                state.cache = @as(u8, bus.read(cpu.regs.pc) & 0xFF);
                cpu.regs.pc +%= 1;
                state.step = 1;
                break :blk null;
            },
            1 => blk: {
                state.step = 0;
                break :blk state.cache;
            },
            else => unreachable,
        };
    }

    pub fn write(_: *Cpu, _: *Peripherals, _: u8) void {
        unreachable;
    }
};

/// 16-bit immediate value pointed by PC
pub const Imm16 = struct {
    /// Read 16-bit value from memory pointed by PC.
    /// Consumes 2 cycles.
    /// Increments PC by 2.
    pub fn read(cpu: *Cpu, bus: *Peripherals) ?u16 {
        const state = struct {
            var step: usize = 0;
            var cache: u16 = 0;
        };
        while (true) {
            switch (state.step) {
                0 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |v| {
                        state.cache = v;
                        state.step = 1;
                        break :blk;
                    }
                    return null;
                },
                1 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |v| {
                        state.cache |= v << 8;
                        state.step = 2;
                        break :blk;
                    }
                    return null;
                },
                2 => {
                    state.step = 0;
                    return state.cache;
                },
                else => unreachable,
            }
        }
    }

    pub fn write(_: *Cpu, _: *Peripherals, _: u16) void {
        unreachable;
    }
};

/// 8-bit value pointed by register pair
pub const Indirect = enum(u8) {
    BC,
    DE,
    HL,
    CFF,
    HLD,
    HLI,

    /// Read 8-bit value from memory pointed by register pair.
    /// Consumes 1 cycle.
    pub fn read(self: @This(), cpu: *Cpu, bus: *Peripherals) ?u8 {
        const state = struct {
            var step: usize = 0;
            var cache: u8 = 0;
        };

        while (true) {
            switch (state.step) {
                0 => {
                    state.cache = @as(u8, switch (self) {
                        .BC => bus.read(cpu.regs.bc()),
                        .DE => bus.read(cpu.regs.de()),
                        .HL => bus.read(cpu.regs.hl()),
                        .CFF => bus.read(0xFF00 | @as(u16, cpu.regs.c)),
                        .HLD => inn: {
                            const addr = cpu.regs.hl();
                            cpu.regs.write_hl(addr -% 1);
                            break :inn bus.read(addr);
                        },
                        .HLI => inn: {
                            const addr = cpu.regs.hl();
                            cpu.regs.write_hl(addr +% 1);
                            break :inn bus.read(addr);
                        },
                    });
                    state.step = 1;
                    return null;
                },
                1 => {
                    state.step = 0;
                    return state.cache;
                },
                else => unreachable,
            }
        }
    }

    /// Write 8-bit value to memory pointed by register pair.
    /// Consumes 1 cycle.
    pub fn write(self: @This(), cpu: *Cpu, bus: *Peripherals, val: u8) ?void {
        const state = struct {
            var step: usize = 0;
            var cache: u8 = 0;
        };

        while (true) {
            switch (state.step) {
                0 => {
                    switch (self) {
                        .BC => bus.write(cpu.regs.bc(), val),
                        .DE => bus.write(cpu.regs.de(), val),
                        .HL => bus.write(cpu.regs.hl(), val),
                        .CFF => bus.write(0xFF00 | @as(u16, cpu.regs.c), val),
                        .HLD => {
                            const addr = cpu.regs.hl();
                            cpu.regs.write_hl(addr -% 1);
                            bus.write(addr, val);
                        },
                        .HLI => {
                            const addr = cpu.regs.hl();
                            cpu.regs.write_hl(addr +% 1);
                            bus.write(addr, val);
                        },
                    }
                    state.step = 1;
                    return null;
                },
                1 => {
                    state.step = 0;
                    return;
                },
                else => unreachable,
            }
        }
    }
};

/// 8-bit value pointed by the value pointed by PC
pub const Direct8 = enum(u8) {
    D,
    DFF,

    /// Read 8-bit value from memory pointed by the addr pointed by PC 16-bit.
    /// Consumes 3 cycles for D, 2 cycles for DFF.
    /// Increments PC by 2 for D, 1 for DFF.
    pub fn read(self: @This(), cpu: *Cpu, bus: *Peripherals) ?u8 {
        const state = struct {
            var step: usize = 0;
            var cache: u16 = 0;
        };

        while (true) {
            switch (state.step) {
                0 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |lo| {
                        state.cache = @as(u16, lo);
                        switch (self) {
                            .D => state.step = 1,
                            .DFF => {
                                state.cache |= 0xFF00;
                                state.step = 2;
                            },
                        }
                        break :blk;
                    }
                    return null;
                },
                1 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |hi| {
                        state.cache |= @as(u16, hi) << 8;
                        state.step = 2;
                        break :blk;
                    }
                    return null;
                },
                2 => {
                    state.cache = bus.read(state.cache);
                    state.step = 3;
                    return null;
                },
                3 => {
                    state.step = 0;
                    return @intCast(state.cache & 0xFF);
                },
                else => unreachable,
            }
        }
    }

    /// Write 8-bit value to memory pointed by the addr pointed by PC 16-bit.
    /// Consumes 3 cycles for D, 2 cycles for DFF.
    /// Increments PC by 2 for D, 1 for DFF.
    pub fn write(self: @This(), cpu: *Cpu, bus: *Peripherals, val: u8) ?void {
        const state = struct {
            var step: usize = 0;
            var cache: u16 = 0;
        };

        while (true) {
            switch (state.step) {
                0 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |lo| {
                        state.cache = @as(u16, lo);
                        switch (self) {
                            .D => state.step = 1,
                            .DFF => {
                                state.cache |= 0xFF00;
                                state.step = 2;
                            },
                        }
                        break :blk;
                    }
                    return null;
                },
                1 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |hi| {
                        state.cache |= @as(u16, hi) << 8;
                        state.step = 2;
                        break :blk;
                    }
                    return null;
                },
                2 => {
                    bus.write(state.cache, val);
                    state.step = 3;
                    return null;
                },
                3 => {
                    state.step = 0;
                    return;
                },
                else => unreachable,
            }
        }
    }
};

/// 16-bit value pointed by the value pointed by PC
pub const Direct16 = struct {
    pub fn read(_: *Cpu, _: *Peripherals) ?u16 {
        unreachable;
    }

    /// Write 16-bit value to memory pointed by the addr pointed by PC 16-bit.
    /// Consumes 4 cycles.
    /// Increments PC by 2.
    pub fn write(cpu: *Cpu, bus: *Peripherals, val: u16) ?void {
        const state = struct {
            var step: usize = 0;
            var cache: u16 = 0;
        };

        while (true) {
            switch (state.step) {
                0 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |lo| {
                        state.cache = @as(u16, lo);
                        state.step = 1;
                        break :blk;
                    }
                    return null;
                },
                1 => blk: {
                    if (@as(Operand, .{ .imm8 = .{} }).read(cpu, bus)) |hi| {
                        state.cache |= @as(u16, hi) << 8;
                        state.step = 2;
                        break :blk;
                    }
                    return null;
                },
                2 => {
                    bus.write(state.cache, @intCast(val & 0xFF));
                    state.step = 3;
                    return null;
                },
                3 => {
                    bus.write(state.cache +% 1, @intCast(val >> 8));
                    state.step = 4;
                    return null;
                },
                4 => {
                    state.step = 0;
                    return;
                },
                else => unreachable,
            }
        }
    }
};

pub const Cond = enum(u8) { NZ, Z, NC, C };

test "reg8" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.write_af(0x1234);
    cpu.regs.write_bc(0x5678);
    try expect(Reg8.A.read(&cpu, &peripherals).? == 0x12);
    try expect(Reg8.C.read(&cpu, &peripherals).? == 0x78);

    Reg8.A.write(&cpu, &peripherals, 0x34);
    Reg8.C.write(&cpu, &peripherals, 0x56);
    try expect(cpu.regs.af() == 0x3430);
    try expect(cpu.regs.bc() == 0x5656);
}

test "imm8" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.pc = 0xC000;
    peripherals.write(cpu.regs.pc, 0x58);
    peripherals.write(cpu.regs.pc + 1, 0xFF);

    try expect(Imm8.read(&cpu, &peripherals) == null);
    try expect(Imm8.read(&cpu, &peripherals) == 0x58);
    try expect(Imm8.read(&cpu, &peripherals) == null);
    try expect(Imm8.read(&cpu, &peripherals) == 0xFF);
    try expect(cpu.regs.pc == 0xC002);
}

test "imm16" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.pc = 0xC000;
    peripherals.write(cpu.regs.pc, 0x58);
    peripherals.write(cpu.regs.pc + 1, 0xFF);
    peripherals.write(cpu.regs.pc + 2, 0x12);
    peripherals.write(cpu.regs.pc + 3, 0x34);

    try expect(Imm16.read(&cpu, &peripherals) == null);
    try expect(Imm16.read(&cpu, &peripherals) == null);
    try expect(Imm16.read(&cpu, &peripherals) == 0xFF58);
    try expect(Imm16.read(&cpu, &peripherals) == null);
    try expect(Imm16.read(&cpu, &peripherals) == null);
    try expect(Imm16.read(&cpu, &peripherals) == 0x3412);
    try expect(cpu.regs.pc == 0xC004);
}

test "indirect read" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.write_bc(0xC080);
    cpu.regs.write_de(0xC001);
    cpu.regs.write_hl(0xC002);
    peripherals.write(0xC001, 0xFF);
    peripherals.write(0xC002, 0x12);
    peripherals.write(0xC080, 0x58);
    peripherals.write(0xFF80, 0x25);

    try expect(Indirect.BC.read(&cpu, &peripherals) == null);
    try expect(Indirect.BC.read(&cpu, &peripherals) == 0x58);
    try expect(Indirect.DE.read(&cpu, &peripherals) == null);
    try expect(Indirect.DE.read(&cpu, &peripherals) == 0xFF);
    try expect(Indirect.HL.read(&cpu, &peripherals) == null);
    try expect(Indirect.HL.read(&cpu, &peripherals) == 0x12);

    try expect(Indirect.CFF.read(&cpu, &peripherals) == null);
    try expect(Indirect.CFF.read(&cpu, &peripherals) == 0x25);

    try expect(cpu.regs.hl() == 0xC002);
    try expect(Indirect.HLD.read(&cpu, &peripherals) == null);
    try expect(Indirect.HLD.read(&cpu, &peripherals) == 0x12);
    try expect(cpu.regs.hl() == 0xC001);

    try expect(Indirect.HLI.read(&cpu, &peripherals) == null);
    try expect(Indirect.HLI.read(&cpu, &peripherals) == 0xFF);
    try expect(cpu.regs.hl() == 0xC002);
}

test "indirect write" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.write_bc(0xC080);
    cpu.regs.write_de(0xC001);
    cpu.regs.write_hl(0xC002);

    try expect(Indirect.BC.write(&cpu, &peripherals, 0x58) == null);
    try expect(Indirect.BC.write(&cpu, &peripherals, 0x58) != null);
    try expect(peripherals.read(0xC080) == 0x58);

    try expect(Indirect.DE.write(&cpu, &peripherals, 0x22) == null);
    try expect(Indirect.DE.write(&cpu, &peripherals, 0x22) != null);
    try expect(peripherals.read(0xC001) == 0x22);

    try expect(Indirect.HL.write(&cpu, &peripherals, 0x19) == null);
    try expect(Indirect.HL.write(&cpu, &peripherals, 0x19) != null);
    try expect(peripherals.read(0xC002) == 0x19);

    try expect(Indirect.CFF.write(&cpu, &peripherals, 0x34) == null);
    try expect(Indirect.CFF.write(&cpu, &peripherals, 0x34) != null);
    try expect(peripherals.read(0xFF80) == 0x34);

    try expect(Indirect.HLD.write(&cpu, &peripherals, 0x25) == null);
    try expect(Indirect.HLD.write(&cpu, &peripherals, 0x25) != null);
    try expect(peripherals.read(0xC002) == 0x25);
    try expect(cpu.regs.hl() == 0xC001);

    try expect(Indirect.HLI.write(&cpu, &peripherals, 0x99) == null);
    try expect(Indirect.HLI.write(&cpu, &peripherals, 0x99) != null);
    try expect(peripherals.read(0xC001) == 0x99);
    try expect(cpu.regs.hl() == 0xC002);
}

test "direct8 IO" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.pc = 0xC000;
    peripherals.write(cpu.regs.pc, 0x80);
    peripherals.write(cpu.regs.pc + 1, 0xFF);
    peripherals.write(0xFF80, 0x33);

    try expect(Direct8.D.read(&cpu, &peripherals) == null);
    try expect(Direct8.D.read(&cpu, &peripherals) == null);
    try expect(Direct8.D.read(&cpu, &peripherals) == null);
    try expect(Direct8.D.read(&cpu, &peripherals) == 0x33);
    try expect(cpu.regs.pc == 0xC002);

    cpu.regs.pc = 0xC000;
    try expect(Direct8.DFF.read(&cpu, &peripherals) == null);
    try expect(Direct8.DFF.read(&cpu, &peripherals) == null);
    try expect(Direct8.DFF.read(&cpu, &peripherals) == 0x33);
    try expect(cpu.regs.pc == 0xC001);

    cpu.regs.pc = 0xC000;
    try expect(Direct8.D.write(&cpu, &peripherals, 0x99) == null);
    try expect(Direct8.D.write(&cpu, &peripherals, 0x99) == null);
    try expect(Direct8.D.write(&cpu, &peripherals, 0x99) == null);
    try expect(Direct8.D.write(&cpu, &peripherals, 0x99) != null);
    try expect(peripherals.read(0xFF80) == 0x99);
    try expect(cpu.regs.pc == 0xC002);

    cpu.regs.pc = 0xC000;
    try expect(Direct8.DFF.write(&cpu, &peripherals, 0x99) == null);
    try expect(Direct8.DFF.write(&cpu, &peripherals, 0x99) == null);
    try expect(Direct8.DFF.write(&cpu, &peripherals, 0x99) != null);
    try expect(peripherals.read(0xFF80) == 0x99);
    try expect(cpu.regs.pc == 0xC001);
}

test "direct16" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.pc = 0xC000;
    peripherals.write(cpu.regs.pc, 0x80);
    peripherals.write(cpu.regs.pc + 1, 0xFF);
    peripherals.write(cpu.regs.pc + 2, 0x80);
    peripherals.write(cpu.regs.pc + 3, 0xFF);

    try expect(Direct16.write(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x1234) != null);
    try expect(peripherals.read(0xFF80) == 0x34);
    try expect(peripherals.read(0xFF81) == 0x12);
    try expect(cpu.regs.pc == 0xC002);

    try expect(Direct16.write(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write(&cpu, &peripherals, 0x5678) != null);
    try expect(peripherals.read(0xFF80) == 0x78);
    try expect(peripherals.read(0xFF81) == 0x56);
    try expect(cpu.regs.pc == 0xC004);
}

const expect = @import("std").testing.expect;
