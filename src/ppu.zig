/// Mode of Picture Processing Unit
const Mode = enum(u2) {
    /// Waiting for HSYNC sygnal
    HBlank = 0,
    /// Waiting for VSYNC sygnal
    VBlank = 1,
    /// Doing OAM Scan (Object Attribute Memory)
    OamScan = 2,
    /// Doing Bg/Window Pixel Fetch, Sprite Pixel Fetch, and Mix Pixel and Push to LCD
    Drawing = 3,
};

/// Picture Processing Unit
const Ppu = struct {
    mode: Mode,

    pub fn new() @This() {
        return .{
            .mode = .HBlank,
        };
    }
};

test "init PPU" {
    const ppu = Ppu.new();
    try expect(ppu.mode == .HBlank);
}

const expect = @import("std").testing.expect;
