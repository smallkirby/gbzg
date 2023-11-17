const Sixel = @import("render/sixel.zig").Sixel;
const Renderer = @import("lcd.zig").Renderer;
const GameBoy = @import("gbzg.zig").GameBoy;
const Bootrom = @import("bootrom.zig").Bootrom;
const std = @import("std");

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

pub fn start() !void {
    var bootrom_bytes = try read_bootrom();
    const bootrom = Bootrom.new(&bootrom_bytes);

    var sixel = try Sixel.new();
    var r: Renderer = .{
        .sixel = sixel,
    };

    var gb = try GameBoy.new(bootrom, r);
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
    try start();
}
