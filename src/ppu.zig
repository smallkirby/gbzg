const gbzg = @import("gbzg.zig");

/// Mode of Picture Processing Unit
const Mode = enum(u2) {
    /// Waiting for HSYNC sygnal
    HBlank = 0,
    /// Waiting for VSYNC sygnal
    VBlank = 1,
    /// Doing OAM Scan (Object Attribute Memory)
    /// During this Mode2, CPU cannot access OAM.
    OamScan = 2,
    /// Doing Bg/Window Pixel Fetch, Sprite Pixel Fetch, and Mix Pixel and Push to LCD
    /// During this Mode3, CPU cannot access VRAM and OAM.
    Drawing = 3,
};

/// Picture Processing Unit
pub const Ppu = struct {
    /// Mode of PPU
    mode: Mode,
    /// LCD Control Register (address: 0xFF40)
    ///  7: LCD Display Enable
    ///  6: Window Tile Map Display Select
    ///  5: Window Display Enable
    ///  4: BG & Window Tile Data Select Mode
    ///  3: BG Tile Map Display Select
    ///  2: OBJ (Sprite) Size
    ///  1: OBJ (Sprite) Display Enable
    ///  0: BG & Window Display Enable. Set to 0 to draw only sprite.
    lcdc: u8,
    /// LCD Status Register (address: 0xFF41)
    ///  7: always 1
    ///  6: LYC=LY Coincidence Interrupt
    ///  5: OAM Scan Mode Interrupt
    ///  4: VBlank Interrupt
    ///  3: HBlank Interrupt
    ///  2: LYC=LY Coincidence Flag
    ///  1-0: Mode Flag (RO)
    stat: u8,
    /// Scroll Y (address: 0xFF42)
    scy: u8,
    /// Scroll X (address: 0xFF43)
    scx: u8,
    /// Line Number currently rendering  (address: 0xFF44)
    ly: u8,
    /// Line Number to trigger LYC=LY Coincidence Interrupt (address: 0xFF45)
    lyc: u8,
    /// Palette of BG and Window (address: 0xFF47)
    bgp: u8,
    /// Object Palette 0 (address: 0xFF48)
    obp0: u8,
    /// Object Palette 1 (address: 0xFF49)
    obp1: u8,
    /// Window Y Position (address: 0xFF4A)
    wy: u8,
    /// Window X Position (address: 0xFF4B)
    wx: u8,

    /// VRAM
    vram: []u8,
    /// OAM (Object Attribute Memory)
    oam: []u8,

    // LCDC Bits
    pub const PPU_ENABLE: u8 = 0b1000_0000;
    pub const WINDOW_TILE_MAP: u8 = 0b0100_0000;
    pub const WINDOW_ENABLE: u8 = 0b0010_0000;
    pub const BG_TILE_DATA_ADDRESSING_MODE: u8 = 0b0001_0000;
    pub const BG_TILE_MAP: u8 = 0b0000_1000;
    pub const SPRITE_SIZE: u8 = 0b0000_0100;
    pub const SPRITE_ENABLE: u8 = 0b0000_0010;
    pub const BG_WINDOW_ENABLE: u8 = 0b0000_0001;

    // STAT Bits
    pub const LYC_EQ_LY_INT: u8 = 0b0100_0000;
    pub const OAM_SCAN_INT: u8 = 0b0010_0000;
    pub const VBLANK_INT: u8 = 0b0001_0000;
    pub const HBLANK_INT: u8 = 0b0000_1000;
    pub const LYC_EQ_LY: u8 = 0b0000_0100;

    pub const VRAM_SIZE = 0x2000; // 8KiB
    pub const OAM_SIZEE = 0xA0; // 160B

    pub fn new() !@This() {
        const vram = try gbzg.ppu_allocator.alloc([VRAM_SIZE]u8, 1);
        const oam = try gbzg.ppu_allocator.alloc([OAM_SIZEE]u8, 1);
        return .{
            .mode = .HBlank,
            .lcdc = 0,
            .stat = 0,
            .scy = 0,
            .scx = 0,
            .ly = 0,
            .lyc = 0,
            .bgp = 0,
            .obp0 = 0,
            .obp1 = 0,
            .wy = 0,
            .wx = 0,
            .vram = &vram[0],
            .oam = &oam[0],
        };
    }

    pub fn read(self: @This(), addr: u16) u8 {
        return switch (addr) {
            0x8000...0x9FFF => blk: {
                if (self.mode == .Drawing) {
                    // cannot read VRAM during Drawing Mode
                    break :blk 0xFF;
                } else {
                    break :blk self.vram[addr & 0x1FFF];
                }
            },
            0xFE00...0xFE9F => blk: {
                if (self.mode == .OamScan or self.mode == .Drawing) {
                    // cannot read OAM during OAM Scan Mode or Drawing Mode
                    break :blk 0xFF;
                } else {
                    break :blk self.oam[addr & 0xFF];
                }
            },
            0xFF40 => self.lcdc,
            0xFF41 => self.stat,
            0xFF42 => self.scy,
            0xFF43 => self.scx,
            0xFF44 => self.ly,
            0xFF45 => self.lyc,
            0xFF47 => self.bgp,
            0xFF48 => self.obp0,
            0xFF49 => self.obp1,
            0xFF4A => self.wy,
            0xFF4B => self.wx,
            else => unreachable,
        };
    }

    pub fn write(self: *@This(), addr: u16, val: u8) void {
        switch (addr) {
            0x8000...0x9FFF => if (self.mode != .Drawing) {
                // cannot write VRAM during Drawing Mode
                self.vram[addr & 0x1FFF] = val;
            },
            0xFE00...0xFE9F => if (self.mode != .OamScan and self.mode != .Drawing) {
                self.oam[addr & 0xFF] = val;
            },
            0xFF40 => self.lcdc = val,
            0xFF41 => self.stat = (self.stat & LYC_EQ_LY) | (val & 0b1111_1000),
            0xFF42 => self.scy = val,
            0xFF43 => self.scx = val,
            0xFF44 => {}, // write not allowed
            0xFF45 => self.lyc = val,
            0xFF46 => {
                if (val <= 0xDF) {
                    unreachable;
                } else {
                    unreachable; // TODO: unimplemented
                }
            },
            0xFF47 => self.bgp = val,
            0xFF48 => self.obp0 = val,
            0xFF49 => self.obp1 = val,
            0xFF4A => self.wy = val,
            0xFF4B => self.wx = val,
            else => unreachable,
        }
    }

    /// Each tile is 16 bytes.
    const TILE_IDX_TO_ADDR_SHIFT = 4;

    /// Get pixel from tile specified by tile_idx, row, and col.
    /// `Tile Data is an array of 0x180 `tiles`.
    /// Each `tile` consists of 16 bytes and Tile Data is plamed at 0x0000-0x17FF VRAM.
    /// Each `tile` represens 8x8 `pixel`s.
    /// `Tile` has 8 rows and each row has 2 bytes (16 bits).
    /// `Pixel` is 2 bits and pair of 2 bits in higher/lowrer part of `tile` represents it.
    fn get_pixel_from_tile(self: @This(), tile_idx: usize, row: u3, col: u3) u2 {
        const r = row * 2;
        const c = 7 - col;
        const tile_addr = tile_idx << TILE_IDX_TO_ADDR_SHIFT;
        const low = self.vram[(tile_addr | r) & 0x1FFF];
        const high = self.vram[(tile_addr | r + 1) & 0x1FFF];
        return (@as(u2, @intCast((high >> c) & 1))) << 1 |
            @as(u2, @intCast((low >> c) & 1));
    }
};

test "init PPU" {
    const ppu = try Ppu.new();
    try expect(ppu.mode == .HBlank);
}

test "get_pixel_from_tile" {
    const ppu = try Ppu.new();
    // MSB of each byte is `high`er
    ppu.vram[0] = 0b1111_0110; // i0,r0,low
    ppu.vram[1] = 0b1000_1111; // i0,r0,high
    ppu.vram[18] = 0b1111_0110; // i1,r1,low
    ppu.vram[19] = 0b1000_1111; // i1,r1,high

    try expect(ppu.get_pixel_from_tile(0, 0, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(0, 0, 1) == 0b01);
    try expect(ppu.get_pixel_from_tile(0, 0, 2) == 0b01);
    try expect(ppu.get_pixel_from_tile(0, 0, 3) == 0b01);
    try expect(ppu.get_pixel_from_tile(0, 0, 4) == 0b10);
    try expect(ppu.get_pixel_from_tile(0, 0, 5) == 0b11);
    try expect(ppu.get_pixel_from_tile(0, 0, 6) == 0b11);
    try expect(ppu.get_pixel_from_tile(0, 0, 7) == 0b10);

    try expect(ppu.get_pixel_from_tile(1, 1, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(1, 1, 1) == 0b01);
    try expect(ppu.get_pixel_from_tile(1, 1, 2) == 0b01);
    try expect(ppu.get_pixel_from_tile(1, 1, 3) == 0b01);
    try expect(ppu.get_pixel_from_tile(1, 1, 4) == 0b10);
    try expect(ppu.get_pixel_from_tile(1, 1, 5) == 0b11);
    try expect(ppu.get_pixel_from_tile(1, 1, 6) == 0b11);
    try expect(ppu.get_pixel_from_tile(1, 1, 7) == 0b10);
}

const expect = @import("std").testing.expect;
