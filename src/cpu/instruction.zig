const Cpu = @import("cpu.zig").Cpu;
const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Operand = @import("operand.zig").Operand;

/// Do nothing. Just fetch the next instruction.
pub fn nop(cpu: *Cpu, bus: *Peripherals) void {
    cpu.fetch(bus);
}

pub fn ld(cpu: *Cpu, bus: *Peripherals, dst: Operand, src: Operand) void {
    _ = cpu;
    _ = bus;
    _ = dst;
    _ = src;
}

test "nop" {
    var cpu = Cpu.new();
    var peripherals = try t_init_peripherals();

    const pc = cpu.regs.pc;
    nop(&cpu, &peripherals);
    try expect(cpu.regs.pc == pc + 1);
}

fn t_init_peripherals() !Peripherals {
    const Bootrom = @import("../bootrom.zig").Bootrom;
    var img = [_]u8{ 0x00, 0x00 };
    const bootram = Bootrom.new(&img);
    var peripherals = try Peripherals.new(bootram);

    return peripherals;
}

const expect = @import("std").testing.expect;
