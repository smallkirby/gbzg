const Sixel = @import("render/sixel.zig").Sixel;
const Renderer = @import("lcd.zig").Renderer;
const Controller = @import("controller.zig").Controller;
const GameBoy = @import("gbzg.zig").GameBoy;
const Bootrom = @import("bootrom.zig").Bootrom;
const Cartridge = @import("cartridge.zig").Cartridge;
const std = @import("std");
const Options = @import("gbzg.zig").Options;
const gbzg = @import("gbzg.zig");
const c = @cImport({
    @cInclude("signal.h");
});

fn read_image(path: [:0]const u8) ![]u8 {
    var f = try std.fs.cwd().openFile(path, .{});
    defer f.close();

    const size = (try f.stat()).size;
    const buf = try f.readToEndAlloc(gbzg.default_allocator, size);

    return buf;
}

fn parse_args() !Options {
    var options = Options{};

    var args = std.process.args();
    _ = args.skip();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--boot-only")) {
            options.boot_only = true;
        } else if (std.mem.eql(u8, arg, "--no-graphics")) {
            options.no_graphics = true;
        } else if (std.mem.startsWith(u8, arg, "--cart=")) {
            options.cartridge_path = arg["--cart=".len..];
        } else if (std.mem.startsWith(u8, arg, "--bootrom=")) {
            options.bootrom_path = arg["--bootrom=".len..];
        } else if (std.mem.startsWith(u8, arg, "--exit_at=")) {
            const s = arg["--exit_at=".len..];
            options.exit_at = try std.fmt.parseInt(u16, s, 16);
        } else if (std.mem.eql(u8, arg, "--color")) {
            options.color = true;
        } else if (std.mem.startsWith(u8, arg, "--dump_vram=")) {
            options.vram_dump_path = arg["--dump_vram=".len..];
        } else {
            std.log.err("Unknown argument: {s}\n", .{arg});
            return error.Unreachable;
        }
    }

    return options;
}

fn set_signal_handler(f: *const fn (c_int) callconv(.C) void) !void {
    const signals = [_]c_int{
        c.SIGINT,
        c.SIGTERM,
    };
    for (signals) |sig| {
        if (c.signal(sig, f) == c.SIG_ERR) {
            std.log.err("Failed to set signal handler of : 0x{X}\n", .{sig});
            return error.Unreachable;
        }
    }
}

var saved_gb: ?*GameBoy = null;

fn graceful_exit_prepare() void {
    if (saved_gb) |gb| {
        gb.deinit() catch {
            std.log.err("Failed to deinit GameBoy\n", .{});
        };
        gb.cpu.debug_print_regs();
        dump_vram_if_necessary();
    } else {
        std.log.err("GameBoy is not initialized\n", .{});
    }
}

fn signal_handler(sig: c_int) callconv(.C) void {
    graceful_exit_prepare();
    std.log.info("Received signal: 0x{X}\n", .{sig});
    std.os.exit(1);
}

fn dump_vram_if_necessary() void {
    if (saved_gb.?.options.vram_dump_path) |path| {
        const vram = saved_gb.?.peripherals.ppu.buffer;
        const file = std.fs.cwd().createFile(path, .{}) catch |e| {
            std.log.err("Failed to create file: {}\n", .{e});
            return;
        };
        defer file.close();

        const size =
            if (saved_gb.?.peripherals.ppu.is_cgb) gbzg.LCD_INFO.pixels * 3 else gbzg.LCD_INFO.pixels;
        _ = file.write(vram[0..size]) catch |e| {
            std.log.err("Failed to write to file: {}\n", .{e});
            return;
        };

        std.log.info("Dumped VRAM to: {s}\n", .{path});
    }
}

fn start(options: Options) !void {
    // Setup BootROM
    var bootrom_bytes = try read_image(options.bootrom_path.?);
    const bootrom = Bootrom.new(bootrom_bytes);

    // Initialize Cartridge
    var cartridge = if (options.boot_only) b: {
        break :b try Cartridge.debug_new();
    } else b: {
        const cart_img = try read_image(options.cartridge_path.?);
        break :b try Cartridge.new(cart_img);
    };

    // Setup LCD Renderer
    var sixel = try Sixel.new(options);
    var r: Renderer = .{
        .sixel = &sixel,
    };

    // Setup controller
    var controller = Controller{
        .sixel = &sixel,
    };

    // Setup signal handler
    try set_signal_handler(signal_handler);

    // Initialize GameBoy
    var gb = try GameBoy.new(
        bootrom,
        cartridge,
        r,
        controller,
        options,
    );
    saved_gb = &gb;
    defer {
        gb.deinit() catch unreachable;
        dump_vram_if_necessary();
    }

    gb.run() catch |e| {
        gb.deinit() catch {};
        std.log.err("ERROR:\n{!}", .{e});
        dump_vram_if_necessary();
        unreachable;
    };
}

pub fn panic(
    message: []const u8,
    trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
) noreturn {
    graceful_exit_prepare();
    std.log.err("PANIC: {s}\n", .{message});

    std.builtin.default_panic(message, trace, ret_addr);
}

pub fn main() !void {
    const options = try parse_args();
    if (!options.boot_only and options.cartridge_path == null) {
        std.log.err("ERROR: --cart=<path> is required when not using --boot-only\n", .{});
        return error.Unreachable;
    }
    if (options.bootrom_path == null) {
        std.log.err("ERROR: --bootrom=<path> is required\n", .{});
        return error.Unreachable;
    }

    try start(options);

    std.log.info("End Of Life :)", .{});
}
