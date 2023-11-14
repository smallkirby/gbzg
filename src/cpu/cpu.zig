const Registers = @import("register.zig").Registers;
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

    pub fn new() Cpu {
        return Cpu{
            .regs = Registers.new(),
            .ctx = Ctx.new(),
        };
    }

    /// Fetch the next opcode and increment the PC
    pub fn fetch(self: *@This(), bus: *Peripherals) void {
        self.ctx.opcode = bus.read(self.regs.pc);
        self.regs.pc +%= 1;
        self.ctx.cb = false;
    }

    /// Decode the current opcode then execute it
    pub fn decode(self: *@This(), bus: *Peripherals) void {
        return decodes.decode(self, bus);
    }

    /// Emulate a single cycle
    pub fn emulate_cycle(self: *@This(), bus: *Peripherals) void {
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
