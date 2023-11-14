//! Defines the decode of instruction set.
//! cf: https://izik1.github.io/gbops/index.html

const Cpu = @import("cpu.zig").Cpu;
const Peripherals = @import("../peripherals.zig").Peripherals;
const inst = @import("instruction.zig");

/// Decode the current opcode and execute the instruction.
pub fn decode(cpu: *Cpu, bus: *Peripherals) void {
    switch (cpu.ctx.opcode) {
        0x00 => inst.nop(cpu, bus),
        else => unreachable,
    }
}

test "nop decode" {
    var cpu = Cpu.new();
    var peripherals = try tutil.t_init_peripherals();

    cpu.regs.pc = 0xC000;
    cpu.ctx.opcode = 0x00;
    cpu.decode(&peripherals);
}

const expect = @import("std").testing.expect;
const tutil = @import("test_util.zig");
