const Sixel = @import("render/sixel.zig").Sixel;
const Renderer = @import("lcd.zig").Renderer;
const GameBoy = @import("gbzg.zig").GameBoy;
const Bootrom = @import("bootrom.zig").Bootrom;
const Cartridge = @import("cartridge.zig").Cartridge;
const std = @import("std");
const Options = @import("gbzg.zig").Options;

fn read_bootrom() ![256]u8 {
    var f = try std.fs.cwd().openFile("dmg_bootrom.bin", .{});
    defer f.close();

    var reader = std.io.bufferedReader(f.reader());
    var in_stream = reader.reader();

    var buf: [256]u8 = undefined;
    if (try in_stream.read(buf[0..]) != 256) {
        unreachable;
    }

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
        } else {
            std.log.err("Unknown argument: {s}\n", .{arg});
            return error.Unreachable;
        }
    }

    return options;
}

pub fn start(options: Options) !void {
    var bootrom_bytes = try read_bootrom();
    const bootrom = Bootrom.new(&bootrom_bytes);

    var cartridge = if (options.boot_only) b: {
        break :b try Cartridge.debug_new();
    } else {
        // TODO
        unreachable;
    };

    var sixel = try Sixel.new(options);
    var r: Renderer = .{
        .sixel = sixel,
    };

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

    try start(options);

    std.log.info("End Of Life :)", .{});
}
