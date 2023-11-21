const Cpu = @import("cpu.zig").Cpu;
const Registers = @import("register.zig").Registers;
const Peripherals = @import("../peripherals.zig").Peripherals;
const Cartridge = @import("../cartridge.zig").Cartridge;

pub fn t_init_peripherals() !Peripherals {
    const Bootrom = @import("../bootrom.zig").Bootrom;
    var img = [_]u8{ 0x00, 0x00 };
    const bootram = Bootrom.new(&img);
    const cart = try Cartridge.debug_new();
    var peripherals = try Peripherals.new(bootram, cart, false);

    return peripherals;
}
