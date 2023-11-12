const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;

/// Context necessary to handle multi-cycle instructions
const Ctx = struct {
    /// Current opcode
    opcode: u8,
    /// TODO
    cb: bool,
};

/// CPU implementation
pub const Cpu = struct {
    regs: Registers,
    ctx: Ctx,

    pub fn fetch(self: *Cpu, bus: *Peripherals) void {
        self.ctx.opcode = bus.read(self.regs.pc);
        self.regs.pc +%= 1;
        self.ctx.cb = false;
    }
};

test "Basic fetch" {
    var peripherals = try t_init_peripherals();
    var cpu = t_init_cpu();

    cpu.regs.pc = 0xC000; // WRAM
    cpu.fetch(&peripherals);
    try expect(cpu.ctx.opcode == 0);
    try expect(cpu.regs.pc == 0xC001);
}

fn t_init_cpu() Cpu {
    var regs = Registers{
        .a = 0,
        .b = 0,
        .c = 0,
        .d = 0,
        .e = 0,
        .h = 0,
        .l = 0,
        .f = 0,
        .sp = 0,
        .pc = 0,
    };
    return Cpu{
        .ctx = .{ .opcode = 0, .cb = false },
        .regs = regs,
    };
}

fn t_init_peripherals() !Peripherals {
    const Bootrom = @import("../bootrom.zig").Bootrom;
    var img = [_]u8{ 0x00, 0x00 };
    const bootram = Bootrom.new(&img);
    var peripherals = try Peripherals.new(bootram);

    return peripherals;
}

const expect = @import("std").testing.expect;
