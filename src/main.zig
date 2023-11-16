const Sixel = @import("render/sixel.zig").Sixel;

pub fn main() !void {
    var sixel = try Sixel.new();
    defer {
        sixel.deinit() catch {}; // TODO: handle error
    }

    try sixel.encode();
}
