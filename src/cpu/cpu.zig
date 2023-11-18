const Registers = @import("register.zig").Registers;
const Interrupts = @import("../interrupts.zig").Interrupts;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Opcode = @import("instruction.zig").Opcode;
const decodes = @import("decode.zig");
const insts = @import("instruction.zig");
const InterruptsEnableBits = @import("../interrupts.zig").Interrupts.InterruptsEnableBits;

/// Context necessary to handle multi-cycle instructions
const Ctx = struct {
    /// Current opcode
    opcode: u8,
    /// Now parsing 0xCB prefixed instructions
    cb: bool,
    /// Now handling an interrupt
    intr: bool,

    pub fn new() Ctx {
        return Ctx{
            .opcode = 0,
            .cb = false,
            .intr = false,
        };
    }
};

/// CPU implementation
pub const Cpu = struct {
    regs: Registers,
    ctx: Ctx,
    /// Interrupts
    interrupts: Interrupts,

    pub fn new() Cpu {
        return Cpu{
            .regs = Registers.new(),
            .ctx = Ctx.new(),
            .interrupts = Interrupts.new(),
        };
    }

    /// Fetch the next opcode and increment the PC
    pub fn fetch(self: *@This(), bus: *Peripherals) void {
        self.ctx.opcode = bus.read(&self.interrupts, self.regs.pc);
        if (self.interrupts.ime and self.interrupts.get_interrupt() != 0) {
            self.ctx.intr = true;
        } else {
            self.regs.pc +%= 1;
            self.ctx.intr = false;
        }
        self.ctx.cb = false;
    }

    /// Decode the current opcode then execute it
    pub fn decode(self: *@This(), bus: *Peripherals) void {
        if (self.ctx.cb) {
            decodes.cb_decode(self, bus);
        } else {
            decodes.decode(self, bus);
        }
    }

    /// Emulate a single cycle
    pub fn emulate_cycle(self: *@This(), bus: *Peripherals) void {
        //self.debug_print_regs();

        if (self.ctx.intr) {
            self.call_isr(bus);
        } else {
            self.decode(bus);
        }
    }

    /// Call the interrupt service routine.
    /// Consumes 5-M cycles.
    pub fn call_isr(self: *@This(), bus: *Peripherals) void {
        const state = struct {
            var step: u8 = 0;
        };

        switch (state.step) {
            0 => if (insts.push16(self, bus, self.regs.pc)) |_| {
                const highest_intr = InterruptsEnableBits.get_highest(self.interrupts.get_interrupt());
                self.interrupts.int_flags &= ~@intFromEnum(highest_intr);

                self.regs.pc = switch (highest_intr) {
                    .VBLANK => 0x40,
                    .STAT => 0x48,
                    .TIMER => 0x50,
                    .SERIAL => 0x58,
                    .JOYPAD => 0x60,
                    _ => unreachable,
                };

                state.step = 1;
            },
            1 => {
                self.interrupts.ime = false;
                state.step = 0;
                self.fetch(bus);
            },
            else => unreachable,
        }
    }

    fn debug_print_regs(self: @This()) void {
        const print = @import("std").debug.print;
        print("PC={X:0>4} OP={X:0>2} ", .{ self.regs.pc, self.ctx.opcode });
        print("A={X:0>2} F={X:0>2} ", .{ self.regs.a, self.regs.f });
        print("B={X:0>2} C={X:0>2} ", .{ self.regs.b, self.regs.c });
        print("D={X:0>2} E={X:0>2} ", .{ self.regs.d, self.regs.e });
        print("H={X:0>2} L={X:0>2} ", .{ self.regs.h, self.regs.l });
        print("SP={X:0>4}\n", .{self.regs.sp});
    }
};

test "Basic fetch" {
    var peripherals = try tutil.t_init_peripherals();
    var cpu = Cpu.new();

    cpu.regs.pc = 0xC000; // WRAM
    cpu.fetch(&peripherals);
    try expect(cpu.ctx.opcode == 0x00);
    try expect(cpu.regs.pc == 0xC001);
}

test "interrupt" {
    var peripherals = try tutil.t_init_peripherals();
    var cpu = Cpu.new();
    const IBE = InterruptsEnableBits;
    const nops = [_]u8{0x00} ** 0x80;

    cpu.regs.pc = 0xC000;
    cpu.regs.sp = 0xC800;
    for (0..nops.len) |i| {
        peripherals.write(
            &cpu.interrupts,
            cpu.regs.pc + @as(u16, @intCast(i)),
            nops[i],
        );
    }
    cpu.interrupts.int_flags =
        @intFromEnum(IBE.JOYPAD) |
        @intFromEnum(IBE.VBLANK) |
        @intFromEnum(IBE.SERIAL);
    cpu.interrupts.ime = true;
    cpu.interrupts.int_enable =
        @intFromEnum(IBE.JOYPAD) |
        @intFromEnum(IBE.VBLANK);

    cpu.fetch(&peripherals);
    try expect(cpu.regs.pc == 0xC000);
    try expect(cpu.ctx.intr == true);

    for (0..4) |_| {
        cpu.emulate_cycle(&peripherals);
    }
    try expect(cpu.regs.pc == 0x40); // VBLANK
    try expect(cpu.ctx.intr == true);

    cpu.emulate_cycle(&peripherals);
    try expect(cpu.regs.pc == 0x40 + 1);
    try expect(cpu.interrupts.ime == false); // interrupt disabled during handling interrupt
    try expect(cpu.ctx.intr == false);
    try expect(
        cpu.interrupts.int_flags ==
            @intFromEnum(IBE.SERIAL) |
            @intFromEnum(IBE.JOYPAD),
    );
}

const std = @import("std");
const expect = std.testing.expect;
const tutil = @import("test_util.zig");
