const Sixel = @import("render/sixel.zig").Sixel;
const Renderer = @import("lcd.zig").Renderer;
const GameBoy = @import("gbzg.zig").GameBoy;
const Bootrom = @import("bootrom.zig").Bootrom;

pub fn main() !void {
    var sixel = try Sixel.new();
    var r: Renderer = .{
        .sixel = sixel,
    };
    var image = ([_]u8{0xFF} ** 160 ** 50) ++ ([_]u8{0x00} ** 160 ** 50) ++ ([_]u8{0x55} ** 160 ** (144 - 100));
    const bootrom = Bootrom.new(&image);

    var gb = try GameBoy.new(bootrom, r);
    defer {
        gb.deinit() catch unreachable;
    }
}
