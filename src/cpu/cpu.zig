const Registers = @import("register.zig").Registers;
const Interrupts = @import("../interrupts.zig").Interrupts;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Opcode = @import("instruction.zig").Opcode;
const decodes = @import("decode.zig");

/// Context necessary to handle multi-cycle instructions
const Ctx = struct {
    /// Current opcode
    opcode: u8,
    /// Now parsing 0xCB prefixed instructions
    cb: bool,

    pub fn new() Ctx {
        return Ctx{
            .opcode = 0,
            .cb = false,
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
        self.regs.pc +%= 1;
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
        self.decode(bus);
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

const expect = @import("std").testing.expect;
const tutil = @import("test_util.zig");
