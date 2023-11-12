const Cpu = @import("cpu.zig").Cpu;
const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;

/// Instruction implementation
pub const Opcode = enum(u8) {
    NOP = 0,

    pub fn execute(self: Opcode, cpu: *Cpu, bus: *Peripherals) void {
        switch (self) {
            .NOP => Opcode.nop(cpu, bus),
        }
    }

    /// Do nothing. Just fetch the next instruction.
    fn nop(cpu: *Cpu, bus: *Peripherals) void {
        cpu.fetch(bus);
    }
};

test "nop" {
    var cpu = t_init_cpu();
    var peripherals = try t_init_peripherals();

    const pc = cpu.regs.pc;
    Opcode.NOP.execute(&cpu, &peripherals);
    try expect(cpu.regs.pc == pc + 1);
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
        .ctx = .{ .opcode = .NOP, .cb = false },
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
