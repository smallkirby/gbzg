const Peripherals = @import("../peripherals.zig").Peripherals;
const Cpu = @import("cpu.zig").Cpu;

pub const Operand = union {
    operand8: Operand8,
    operand16: Operand16,
};

pub const Operand8 = union {
    reg: Reg8,
    imm: Imm8,
    indirect: Indirect,
    direct: Direct8,
};
pub const Operand16 = union {
    reg: Reg16,
    imm: Imm16,
    derect: Direct16,
};

pub fn read8(cpu: *Cpu, peripherals: *Peripherals, operand: Operand8) ?u8 {
    return switch (operand) {
        .reg => Reg8.read8(cpu, peripherals, operand.reg),
        .imm => Imm8.read8(cpu, peripherals),
        .indirect => unreachable,
        .direct => unreachable,
    };
}

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
    pub fn read8(cpu: *Cpu, _: *Peripherals, src: Reg8) ?u8 {
        return switch (src) {
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
    pub fn write8(cpu: *Cpu, _: *Peripherals, dst: Reg8, val: u8) void {
        switch (dst) {
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

pub const Reg16 = enum(u8) {
    AF,
    BC,
    DE,
    HL,
    SP,

    /// Read 16-bit value from register pair.
    /// Consumes 0 cycles.
    pub fn read16(cpu: *Cpu, _: *Peripherals, src: Reg16) ?u16 {
        return switch (src) {
            .AF => cpu.regs.af(),
            .BC => cpu.regs.bc(),
            .DE => cpu.regs.de(),
            .HL => cpu.regs.hl(),
            .SP => cpu.regs.sp,
        };
    }

    /// Write 16-bit value to register pair
    /// Consumes 0 cycles.
    pub fn write16(cpu: *Cpu, _: *Peripherals, dst: Reg16, val: u16) void {
        switch (dst) {
            .AF => cpu.regs.write_af(val),
            .BC => cpu.regs.write_bc(val),
            .DE => cpu.regs.write_de(val),
            .HL => cpu.regs.write_hl(val),
            .SP => cpu.regs.sp = val,
        }
    }
};

pub const Imm8 = struct {
    /// Read 8-bit value from memory pointed by PC.
    /// Consumes 1 cycle.
    /// Increments PC by 1.
    pub fn read8(cpu: *Cpu, bus: *Peripherals) ?u8 {
        return switch (cpu.ctx.mem_ctx.step orelse 0) {
            0 => blk: {
                cpu.ctx.mem_ctx.cache = @as(u16, bus.read(cpu.regs.pc));
                cpu.ctx.mem_ctx.step = 1;
                cpu.regs.pc +%= 1;
                break :blk null;
            },
            1 => blk: {
                cpu.ctx.mem_ctx.step = null;
                break :blk @as(u8, @intCast(cpu.ctx.mem_ctx.cache.? & 0xFF));
            },
            else => unreachable,
        };
    }

    pub fn write8(_: *Cpu, _: *Peripherals, _: Imm8, _: u8) void {
        unreachable;
    }
};

pub const Imm16 = struct {
    /// Read 16-bit value from memory pointed by PC.
    /// Consumes 2 cycles.
    /// Increments PC by 2.
    pub fn read16(cpu: *Cpu, bus: *Peripherals) ?u16 {
        return switch (cpu.ctx.mem_ctx.step orelse 0) {
            0 => blk: {
                cpu.ctx.mem_ctx.cache = bus.read(cpu.regs.pc);
                cpu.ctx.mem_ctx.step = 1;
                cpu.regs.pc +%= 1;
                break :blk null;
            },
            1 => blk: {
                cpu.ctx.mem_ctx.cache.? |= @as(u16, bus.read(cpu.regs.pc)) << 8;
                cpu.ctx.mem_ctx.step = 2;
                cpu.regs.pc +%= 1;
                break :blk null;
            },
            2 => blk: {
                cpu.ctx.mem_ctx.step = null;
                break :blk cpu.ctx.mem_ctx.cache.?;
            },
            else => unreachable,
        };
    }

    pub fn write16(_: *Cpu, _: *Peripherals, _: Imm16, _: u16) void {
        unreachable;
    }
};

pub const Indirect = enum(u8) {
    BC,
    DE,
    HL,
    CFF,
    HLD,
    HLI,

    /// Read 8-bit value from memory pointed by register pair.
    /// Consumes 1 cycle.
    pub fn read8(cpu: *Cpu, bus: *Peripherals, src: Indirect) ?u8 {
        return switch (cpu.ctx.mem_ctx.step orelse 0) {
            0 => blk: {
                cpu.ctx.mem_ctx.cache = switch (src) {
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
                };
                cpu.ctx.mem_ctx.step = 1;
                break :blk null;
            },
            1 => blk: {
                cpu.ctx.mem_ctx.step = null;
                break :blk @intCast(cpu.ctx.mem_ctx.cache.? & 0xFF);
            },
            else => unreachable,
        };
    }

    /// Write 8-bit value to memory pointed by register pair.
    /// Consumes 1 cycle.
    pub fn write8(cpu: *Cpu, bus: *Peripherals, dst: Indirect, val: u8) ?void {
        return switch (cpu.ctx.mem_ctx.step orelse 0) {
            0 => blk: {
                switch (dst) {
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
                cpu.ctx.mem_ctx.step = 1;
                break :blk null;
            },
            1 => {
                cpu.ctx.mem_ctx.step = null;
            },
            else => unreachable,
        };
    }
};

pub const Direct8 = enum(u8) {
    D,
    DFF,

    /// Read 8-bit value from memory pointed by the addr pointed by PC 16-bit.
    /// Consumes 3 cycles for D, 2 cycles for DFF.
    /// Increments PC by 2 for D, 1 for DFF.
    pub fn read8(cpu: *Cpu, bus: *Peripherals, src: Direct8) ?u8 {
        return switch (cpu.ctx.mem_ctx.step orelse 0) {
            0 => blk: {
                cpu.ctx.mem_ctx.cache = @as(u16, bus.read(cpu.regs.pc));
                cpu.regs.pc +%= 1;
                switch (src) {
                    .D => cpu.ctx.mem_ctx.step = 1,
                    .DFF => cpu.ctx.mem_ctx.step = 2,
                }
                break :blk null;
            },
            1 => blk: {
                cpu.ctx.mem_ctx.cache.? |= @as(u16, bus.read(cpu.regs.pc)) << 8;
                cpu.regs.pc +%= 1;
                cpu.ctx.mem_ctx.step = 2;
                break :blk null;
            },
            2 => blk: {
                if (src == .DFF) {
                    cpu.ctx.mem_ctx.cache.? |= 0xFF00;
                }
                cpu.ctx.mem_ctx.cache = bus.read(cpu.ctx.mem_ctx.cache.?);
                cpu.ctx.mem_ctx.step = 3;
                break :blk null;
            },
            3 => blk: {
                cpu.ctx.mem_ctx.step = null;
                break :blk @intCast(cpu.ctx.mem_ctx.cache.? & 0xFF);
            },
            else => unreachable,
        };
    }

    /// Write 8-bit value to memory pointed by the addr pointed by PC 16-bit.
    /// Consumes 3 cycles for D, 2 cycles for DFF.
    /// Increments PC by 2 for D, 1 for DFF.
    pub fn write8(cpu: *Cpu, bus: *Peripherals, dst: Direct8, val: u8) ?void {
        return switch (cpu.ctx.mem_ctx.step orelse 0) {
            0 => blk: {
                cpu.ctx.mem_ctx.cache = @as(u16, bus.read(cpu.regs.pc));
                cpu.regs.pc +%= 1;
                switch (dst) {
                    .D => cpu.ctx.mem_ctx.step = 1,
                    .DFF => cpu.ctx.mem_ctx.step = 2,
                }
                break :blk null;
            },
            1 => blk: {
                cpu.ctx.mem_ctx.cache.? |= @as(u16, bus.read(cpu.regs.pc)) << 8;
                cpu.regs.pc +%= 1;
                cpu.ctx.mem_ctx.step = 2;
                break :blk null;
            },
            2 => blk: {
                if (dst == .DFF) {
                    cpu.ctx.mem_ctx.cache.? |= 0xFF00;
                }
                bus.write(cpu.ctx.mem_ctx.cache.?, val);
                cpu.ctx.mem_ctx.step = 3;
                break :blk null;
            },
            3 => {
                cpu.ctx.mem_ctx.step = null;
            },
            else => unreachable,
        };
    }
};
pub const Direct16 = struct {
    pub fn read16(_: *Cpu, _: *Peripherals, _: Direct16) ?u16 {
        unreachable;
    }

    /// Write 16-bit value to memory pointed by the addr pointed by PC 16-bit.
    /// Consumes 4 cycles.
    /// Increments PC by 2.
    pub fn write16(cpu: *Cpu, bus: *Peripherals, val: u16) ?void {
        return switch (cpu.ctx.mem_ctx.step orelse 0) {
            0 => blk: {
                cpu.ctx.mem_ctx.cache = @as(u16, bus.read(cpu.regs.pc));
                cpu.regs.pc +%= 1;
                cpu.ctx.mem_ctx.step = 1;
                break :blk null;
            },
            1 => blk: {
                cpu.ctx.mem_ctx.cache.? |= @as(u16, bus.read(cpu.regs.pc)) << 8;
                cpu.regs.pc +%= 1;
                cpu.ctx.mem_ctx.step = 2;
                break :blk null;
            },
            2 => blk: {
                bus.write(cpu.ctx.mem_ctx.cache.?, @intCast(val & 0xFF));
                cpu.ctx.mem_ctx.step = 3;
                break :blk null;
            },
            3 => blk: {
                bus.write(cpu.ctx.mem_ctx.cache.? +% 1, @intCast(val >> 8));
                cpu.ctx.mem_ctx.step = 4;
                break :blk null;
            },
            4 => {
                cpu.ctx.mem_ctx.step = null;
            },
            else => unreachable,
        };
    }
};
pub const Cond = enum(u8) { NZ, Z, NC, C };

test "reg8" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.write_af(0x1234);
    cpu.regs.write_bc(0x5678);
    try expect(Reg8.read8(&cpu, &peripherals, .A).? == 0x12);
    try expect(Reg8.read8(&cpu, &peripherals, .C).? == 0x78);

    Reg8.write8(&cpu, &peripherals, .A, 0x34);
    Reg8.write8(&cpu, &peripherals, .C, 0x56);
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

    try expect(Imm8.read8(&cpu, &peripherals) == null);
    try expect(Imm8.read8(&cpu, &peripherals) == 0x58);
    try expect(Imm8.read8(&cpu, &peripherals) == null);
    try expect(Imm8.read8(&cpu, &peripherals) == 0xFF);
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

    try expect(Imm16.read16(&cpu, &peripherals) == null);
    try expect(Imm16.read16(&cpu, &peripherals) == null);
    try expect(Imm16.read16(&cpu, &peripherals) == 0xFF58);
    try expect(Imm16.read16(&cpu, &peripherals) == null);
    try expect(Imm16.read16(&cpu, &peripherals) == null);
    try expect(Imm16.read16(&cpu, &peripherals) == 0x3412);
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

    try expect(Indirect.read8(&cpu, &peripherals, .BC) == null);
    try expect(Indirect.read8(&cpu, &peripherals, .BC) == 0x58);
    try expect(Indirect.read8(&cpu, &peripherals, .DE) == null);
    try expect(Indirect.read8(&cpu, &peripherals, .DE) == 0xFF);
    try expect(Indirect.read8(&cpu, &peripherals, .HL) == null);
    try expect(Indirect.read8(&cpu, &peripherals, .HL) == 0x12);

    try expect(Indirect.read8(&cpu, &peripherals, .CFF) == null);
    try expect(Indirect.read8(&cpu, &peripherals, .CFF) == 0x25);

    try expect(cpu.regs.hl() == 0xC002);
    try expect(Indirect.read8(&cpu, &peripherals, .HLD) == null);
    try expect(Indirect.read8(&cpu, &peripherals, .HLD) == 0x12);
    try expect(cpu.regs.hl() == 0xC001);

    try expect(Indirect.read8(&cpu, &peripherals, .HLI) == null);
    try expect(Indirect.read8(&cpu, &peripherals, .HLI) == 0xFF);
    try expect(cpu.regs.hl() == 0xC002);
}

test "indirect write" {
    const tutil = @import("test_util.zig");
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.write_bc(0xC080);
    cpu.regs.write_de(0xC001);
    cpu.regs.write_hl(0xC002);

    try expect(Indirect.write8(&cpu, &peripherals, .BC, 0x58) == null);
    try expect(Indirect.write8(&cpu, &peripherals, .BC, 0x58) != null);
    try expect(peripherals.read(0xC080) == 0x58);

    try expect(Indirect.write8(&cpu, &peripherals, .DE, 0x22) == null);
    try expect(Indirect.write8(&cpu, &peripherals, .DE, 0x22) != null);
    try expect(peripherals.read(0xC001) == 0x22);

    try expect(Indirect.write8(&cpu, &peripherals, .HL, 0x19) == null);
    try expect(Indirect.write8(&cpu, &peripherals, .HL, 0x19) != null);
    try expect(peripherals.read(0xC002) == 0x19);

    try expect(Indirect.write8(&cpu, &peripherals, .CFF, 0x34) == null);
    try expect(Indirect.write8(&cpu, &peripherals, .CFF, 0x34) != null);
    try expect(peripherals.read(0xFF80) == 0x34);

    try expect(Indirect.write8(&cpu, &peripherals, .HLD, 0x25) == null);
    try expect(Indirect.write8(&cpu, &peripherals, .HLD, 0x25) != null);
    try expect(peripherals.read(0xC002) == 0x25);
    try expect(cpu.regs.hl() == 0xC001);

    try expect(Indirect.write8(&cpu, &peripherals, .HLI, 0x99) == null);
    try expect(Indirect.write8(&cpu, &peripherals, .HLI, 0x99) != null);
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

    try expect(Direct8.read8(&cpu, &peripherals, .D) == null);
    try expect(Direct8.read8(&cpu, &peripherals, .D) == null);
    try expect(Direct8.read8(&cpu, &peripherals, .D) == null);
    try expect(Direct8.read8(&cpu, &peripherals, .D) == 0x33);
    try expect(cpu.regs.pc == 0xC002);

    cpu.regs.pc = 0xC000;
    try expect(Direct8.read8(&cpu, &peripherals, .DFF) == null);
    try expect(Direct8.read8(&cpu, &peripherals, .DFF) == null);
    try expect(Direct8.read8(&cpu, &peripherals, .DFF) == 0x33);
    try expect(cpu.regs.pc == 0xC001);

    cpu.regs.pc = 0xC000;
    try expect(Direct8.write8(&cpu, &peripherals, .D, 0x99) == null);
    try expect(Direct8.write8(&cpu, &peripherals, .D, 0x99) == null);
    try expect(Direct8.write8(&cpu, &peripherals, .D, 0x99) == null);
    try expect(Direct8.write8(&cpu, &peripherals, .D, 0x99) != null);
    try expect(peripherals.read(0xFF80) == 0x99);
    try expect(cpu.regs.pc == 0xC002);

    cpu.regs.pc = 0xC000;
    try expect(Direct8.write8(&cpu, &peripherals, .DFF, 0x99) == null);
    try expect(Direct8.write8(&cpu, &peripherals, .DFF, 0x99) == null);
    try expect(Direct8.write8(&cpu, &peripherals, .DFF, 0x99) != null);
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

    try expect(Direct16.write16(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x1234) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x1234) != null);
    try expect(peripherals.read(0xFF80) == 0x34);
    try expect(peripherals.read(0xFF81) == 0x12);
    try expect(cpu.regs.pc == 0xC002);

    try expect(Direct16.write16(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x5678) == null);
    try expect(Direct16.write16(&cpu, &peripherals, 0x5678) != null);
    try expect(peripherals.read(0xFF80) == 0x78);
    try expect(peripherals.read(0xFF81) == 0x56);
    try expect(cpu.regs.pc == 0xC004);
}

const expect = @import("std").testing.expect;
