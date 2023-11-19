const std = @import("std");
const Bootrom = @import("bootrom.zig").Bootrom;
const Renderer = @import("lcd.zig").Renderer;
const LCD = @import("lcd.zig").LCD;
const Peripherals = @import("peripherals.zig").Peripherals;
const Cpu = @import("cpu/cpu.zig").Cpu;
const Cartridge = @import("cartridge.zig").Cartridge;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const default_allocator = gpa.allocator();

pub const hram_allocator = default_allocator;
pub const wram_allocator = default_allocator;
pub const ppu_allocator = default_allocator;
pub const cartridge_allocator = default_allocator;

pub const LCD_INFO = struct {
    pub const width: u8 = 160;
    pub const height: u8 = 144;
    pub const pixels: usize = @as(usize, width) * @as(usize, height);
};

/// User-provided options.
pub const Options = struct {
    /// Exit the emulator after the BootROM has finished.
    boot_only: bool = false,
    /// Disable graphics.
    no_graphics: bool = false,
    /// BootROM file path.
    bootrom_path: ?[:0]const u8 = null,
    /// Cartridge file path.
    cartridge_path: ?[:0]const u8 = null,
    /// Exit on PC reaching this address.
    exit_at: ?u16 = null,
    /// Dump VRAM to this file.
    vram_dump_path: ?[:0]const u8 = null,
};

pub const GameBoy = struct {
    cpu: Cpu,
    peripherals: Peripherals,
    lcd: LCD,
    options: Options,

    const CPU_CLOCK_HZ: u128 = 4_194_304;
    const M_CYCLE_CLOCK: u128 = 4;
    const M_CYCLE_NANOS: u128 = M_CYCLE_CLOCK * 1_000_000_000 / CPU_CLOCK_HZ;

    pub fn new(bootrom: Bootrom, cartdige: Cartridge, renderer: Renderer, options: Options) !@This() {
        const peripherals = try Peripherals.new(bootrom, cartdige);
        const lcd = try LCD.new(renderer);
        const cpu = Cpu.new();

        return @This(){
            .cpu = cpu,
            .peripherals = peripherals,
            .lcd = lcd,
            .options = options,
        };
    }

    pub fn deinit(self: @This()) !void {
        try self.lcd.deinit();
    }

    pub fn run(self: *@This()) !void {
        dprint("Start Running...\n", .{});

        var timer = try std.time.Timer.start();
        var elapsed: u128 = 0;

        while (true) {
            const e = timer.read();

            for (0..@as(usize, @intCast((e - elapsed) / M_CYCLE_NANOS))) |_| {
                if (self.options.boot_only and self.cpu.regs.pc == 0x78) {
                    // PC=0x78 jumps to 0xFFE and starts executing the cartridge code.
                    std.log.info("BootROM finished. Exiting...", .{});
                    return;
                }
                if (self.options.exit_at) |at| {
                    if (self.cpu.regs.pc == at) {
                        std.log.info("Reached at specified PC(=0x{X:0>4}). Exiting...", .{self.cpu.regs.pc});
                        return;
                    }
                }

                self.cpu.emulate_cycle(&self.peripherals);
                self.peripherals.timer.emulate_cycle(&self.cpu.interrupts);
                if (self.peripherals.ppu.emulate_cycle()) {
                    try self.lcd.draw(self.peripherals.ppu.buffer);
                }

                elapsed += M_CYCLE_NANOS;
            }
        }
    }
};

const dprint = @import("std").debug.print;
