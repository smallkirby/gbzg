const std = @import("std");
const Bootrom = @import("bootrom.zig").Bootrom;
const Renderer = @import("lcd.zig").Renderer;
const LCD = @import("lcd.zig").LCD;
const Peripherals = @import("peripherals.zig").Peripherals;
const Cpu = @import("cpu/cpu.zig").Cpu;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const default_allocator = gpa.allocator();

pub const hram_allocator = default_allocator;
pub const wram_allocator = default_allocator;
pub const ppu_allocator = default_allocator;

pub const LCD_INFO = struct {
    pub const width: u8 = 160;
    pub const height: u8 = 144;
    pub const pixels: usize = @as(usize, width) * @as(usize, height);
};

pub const GameBoy = struct {
    cpu: Cpu,
    peripherals: Peripherals,
    lcd: LCD,

    const CPU_CLOCK_HZ: u128 = 4_194_304;
    const M_CYCLE_CLOCK: u128 = 4;
    const M_CYCLE_NANOS: u128 = M_CYCLE_CLOCK * 1_000_000_000 / CPU_CLOCK_HZ;

    pub fn new(bootrom: Bootrom, renderer: Renderer) !@This() {
        const peripherals = try Peripherals.new(bootrom);
        const lcd = try LCD.new(renderer);
        const cpu = Cpu.new();

        return @This(){
            .cpu = cpu,
            .peripherals = peripherals,
            .lcd = lcd,
        };
    }

    pub fn deinit(self: @This()) !void {
        try self.lcd.deinit();
    }

    pub fn run(self: @This()) !void {
        const timer = try std.time.Timer.start();
        var elapsed = 0;

        while (true) {
            const e = timer.lap();
            for (0..e / M_CYCLE_NANOS) |_| {
                self.cpu.emulate_cycle(self.peripherals);
                if (self.peripherals.ppu.emulate_cycle()) {
                    self.lcd.draw(self.peripherals.ppu.buffer);
                }

                elapsed += M_CYCLE_NANOS;
            }
        }
    }
};
