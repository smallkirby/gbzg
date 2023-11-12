const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Opcode = @import("instruction.zig").Opcode;

/// Context necessary to handle multi-cycle instructions
const Ctx = struct {
    /// Current opcode
    opcode: u8,
    /// Now parsing 0xCB prefixed instructions
    cb: bool,
    /// multi-cycle information for memory IO
    mem_ctx: StepInfo,
    /// multi-cycle information for instructions
    inst_ctx: StepInfo,

    pub fn new() Ctx {
        return Ctx{
            .opcode = 0,
            .cb = false,
            .mem_ctx = StepInfo.new(),
            .inst_ctx = StepInfo.new(),
        };
    }
};

const StepInfo = struct {
    step: ?u8,
    cache: ?u16,

    pub fn new() StepInfo {
        return StepInfo{
            .step = null,
            .cache = null,
        };
    }
};

/// CPU implementation
pub const Cpu = struct {
    regs: Registers,
    ctx: Ctx,

    pub fn new() Cpu {
        return Cpu{
            .regs = Registers.new(),
            .ctx = Ctx.new(),
        };
    }

    pub fn fetch(self: *Cpu, bus: *Peripherals) void {
        self.ctx.opcode = bus.read(self.regs.pc);
        self.regs.pc +%= 1;
        self.ctx.cb = false;
    }

    pub fn decode(self: *Cpu, bus: *Peripherals) void {
        switch (self.ctx.opcode) {
            0x00 => self.nop(bus),
            else => @compileError("Unimplemented opcode"),
        }
    }

    pub fn emulate_cycle(self: *Cpu, bus: *Peripherals) void {
        self.decode(bus);
    }
};

test "Basic fetch" {
    var peripherals = try t_init_peripherals();
    var cpu = Cpu.new();

    cpu.regs.pc = 0xC000; // WRAM
    cpu.fetch(&peripherals);
    try expect(cpu.ctx.opcode == 0x00);
    try expect(cpu.regs.pc == 0xC001);
}

fn t_init_peripherals() !Peripherals {
    const Bootrom = @import("../bootrom.zig").Bootrom;
    var img = [_]u8{ 0x00, 0x00 };
    const bootram = Bootrom.new(&img);
    var peripherals = try Peripherals.new(bootram);

    return peripherals;
}

const expect = @import("std").testing.expect;
