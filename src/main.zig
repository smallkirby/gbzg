const Sixel = @import("render/sixel.zig").Sixel;
const Renderer = @import("lcd.zig").Renderer;
const GameBoy = @import("gbzg.zig").GameBoy;
const Bootrom = @import("bootrom.zig").Bootrom;
const Cartridge = @import("cartridge.zig").Cartridge;
const std = @import("std");
const Options = @import("gbzg.zig").Options;
const gbzg = @import("gbzg.zig");

fn read_bootrom(path: [:0]const u8) ![256]u8 {
    var f = try std.fs.cwd().openFile(path, .{});
    defer f.close();

    var reader = std.io.bufferedReader(f.reader());
    var in_stream = reader.reader();

    var buf: [256]u8 = undefined;
    if (try in_stream.read(buf[0..]) != 256) {
        unreachable;
    }

    return buf;
}

fn read_cartridge(path: [:0]const u8) ![]u8 {
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
        } else {
            std.log.err("Unknown argument: {s}\n", .{arg});
            return error.Unreachable;
        }
    }

    return options;
}

pub fn start(options: Options) !void {
    // Setup BootROM
    var bootrom_bytes = try read_bootrom(options.bootrom_path.?);
    const bootrom = Bootrom.new(&bootrom_bytes);

    // Initialize Cartridge
    var cartridge = if (options.boot_only) b: {
        break :b try Cartridge.debug_new();
    } else b: {
        const cart_img = try read_cartridge(options.cartridge_path.?);
        break :b try Cartridge.new(cart_img);
    };

    // Setup LCD Renderer
    var sixel = try Sixel.new(options);
    var r: Renderer = .{
        .sixel = sixel,
    };

    // Initialize GameBoy
    var gb = try GameBoy.new(bootrom, cartridge, r, options);
    defer {
        gb.deinit() catch unreachable;
    }

    gb.run() catch |e| {
        gb.deinit() catch {};
        std.log.err("ERROR:\n{!}", .{e});
        unreachable;
    };
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
