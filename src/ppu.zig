const gbzg = @import("gbzg.zig");
const LCD_INFO = gbzg.LCD_INFO;

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
    /// It has 4 colors and each color is 2 bits.
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
    /// LCD buffer
    buffer: []u8,

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

    const COLOR = struct {
        pub const WHITE: u8 = 0xFF;
        pub const LIGHT_GRAY: u8 = 0xAA;
        pub const DARK_GRAY: u8 = 0x55;
        pub const BLACK: u8 = 0x00;
    };

    pub fn new() !@This() {
        const vram = try gbzg.ppu_allocator.alloc([VRAM_SIZE]u8, 1);
        const oam = try gbzg.ppu_allocator.alloc([OAM_SIZEE]u8, 1);
        const buffer = try gbzg.ppu_allocator.alloc([LCD_INFO.pixels]u8, 1);
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
            .buffer = &buffer[0],
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

    /// Get pixel from Tile in Tile Data specified by tile_idx, row, and col.
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

    /// Tile Map consists of 32x32 array of 8bit tile index.
    /// One tile represents 8x8 pixel, hence Tile Map represents 256x256 pixel.
    pub const TileMapInfo = struct {
        pub const ROWS: usize = 32;
        pub const COLS: usize = 32;
        pub const SIZE: usize = ROWS * COLS;
        pub const AddrOne: usize = 0x1800;
        pub const AddrTwo: usize = AddrOne + SIZE;
    };

    // Tile represents 8x8 pixel.
    // A row of tile consists of 2 bytes (16 bits) and represents 8 pixel.
    pub const TileInfo = struct {
        pub const WIDTH: u8 = 8;
        pub const HEIGHT: u8 = 8;
    };

    /// Tile Data is an array of 0x180 `tiles`.
    /// Each tile represents 8x8 pixel.
    pub const TileDataInfo = struct {
        pub const SIZE: usize = 0x180;
    };

    /// Get tile index from Tile Map.
    /// One entry of Tile Map is 8-bit, while Tile Data has 0x180 entries.
    /// Therefore, if 4th bit of LCDC is 1, Tile Map 1 is used and Tile Map 2 is used otherwise.
    fn get_tile_idx_from_tile_map(self: @This(), time_map: u1, row: u8, col: u8) usize {
        const start_addr = if (time_map == 0)
            TileMapInfo.AddrOne
        else
            TileMapInfo.AddrTwo;
        const ret = self.vram[start_addr + (row * TileMapInfo.COLS) + col];

        if (self.lcdc & BG_TILE_DATA_ADDRESSING_MODE != 0) {
            return ret;
        } else {
            // 0x8000-0x8FFF
            return @as(usize, @intCast(ret)) + 0x100;
        }
    }

    /// Reender background of the current line specified by ly.
    /// LCD is 100x144 pixel, while Tile Map has 256x256 pixel.
    /// Therefore, this function renders 160x144 pixels of Tile Map decided by SCX and SCY.
    /// TODO: function name should be changed to `render_bg_line` ?
    fn render_bg(self: *@This()) void {
        if (self.lcdc & BG_WINDOW_ENABLE == 0) {
            return;
        }

        const y = self.ly +% self.scy;
        for (0..LCD_INFO.width) |i| {
            const x: u8 = @as(u8, @intCast(i & 0xFF)) +% self.scx;
            const tile_idx = self.get_tile_idx_from_tile_map(
                @intFromBool((self.lcdc & BG_TILE_MAP) != 0),
                y / TileInfo.HEIGHT,
                x / TileInfo.WIDTH,
            );
            const pixel = self.get_pixel_from_tile(
                tile_idx,
                @intCast(y % TileInfo.HEIGHT),
                @intCast(x % TileInfo.WIDTH),
            );

            self.buffer[LCD_INFO.width * self.ly + i] = switch ((self.bgp >> ((@as(u3, pixel) * 2))) & 0b11) {
                0 => COLOR.WHITE,
                1 => COLOR.LIGHT_GRAY,
                2 => COLOR.DARK_GRAY,
                3 => COLOR.BLACK,
                else => unreachable,
            };
        }
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

test "get_tile_idx_from_tile_map" {
    const TileMapInfo = Ppu.TileMapInfo;
    var ppu = try Ppu.new();
    const bytes1 = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    } ** 2 // row0
    ++ [_]u8{
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
    } ** 2 // row1
    ;
    const bytes2 = [_]u8{
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
    } ** 2 // row0
    ++ [_]u8{
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
    } ** 2 // row1
    ;
    const tile_map1 = ppu.vram[TileMapInfo.AddrOne..(TileMapInfo.AddrOne + TileMapInfo.SIZE)];
    const tile_map2 = ppu.vram[TileMapInfo.AddrTwo..(TileMapInfo.AddrTwo + TileMapInfo.SIZE)];
    for (bytes1, 0..) |b, i| {
        tile_map1[i] = b;
    }
    for (bytes2, 0..) |b, i| {
        tile_map2[i] = b;
    }

    // LCDC.4 == 1
    ppu.lcdc |= Ppu.BG_TILE_DATA_ADDRESSING_MODE;
    try expect(ppu.get_tile_idx_from_tile_map(0, 0, 0) == 0x00);
    try expect(ppu.get_tile_idx_from_tile_map(0, 0, 2) == 0x02);
    try expect(ppu.get_tile_idx_from_tile_map(0, 1, 6) == 0x16);
    try expect(ppu.get_tile_idx_from_tile_map(1, 1, 2) == 0x32);

    // LCDC.4 == 0
    ppu.lcdc &= ~Ppu.BG_TILE_DATA_ADDRESSING_MODE;
    try expect(ppu.get_tile_idx_from_tile_map(0, 0, 0) == 0x100);
    try expect(ppu.get_tile_idx_from_tile_map(1, 0, 2) == 0x122);
}

test "render_bg" {
    const TileMapInfo = Ppu.TileMapInfo;
    const C = Ppu.COLOR;
    var ppu = try Ppu.new();
    ppu.lcdc |= Ppu.BG_WINDOW_ENABLE;
    ppu.ly = 0;
    ppu.scx = 0;
    ppu.scy = 0;
    ppu.lcdc &= ~Ppu.BG_TILE_MAP; // use Tile Map 0
    ppu.lcdc |= Ppu.BG_TILE_DATA_ADDRESSING_MODE; // use Tile Data 0
    ppu.bgp = 0b11_10_01_00; // BDLW

    // initialize tile map
    const tile_map_bytes = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x1E, 0x1F,
    } ** 32 // 32 rows
    ;
    try expect(tile_map_bytes.len == TileMapInfo.SIZE);
    const tile_map = ppu.vram[TileMapInfo.AddrOne..(TileMapInfo.AddrOne + TileMapInfo.SIZE)];
    for (tile_map_bytes, 0..) |b, i| {
        tile_map[i] = b;
    }

    // initialize tile data
    const tile_bytes1 = [_]u8{
        // Note that letf side is low and right side is high
        // Each byte's MSB is 0-th and LSB is 7-th
        0b1111_0110, 0b1000_1110, // BLLL_DBBW
        0b1111_0110, 0b1000_1110, // BDDD_LBBW
        0b1111_0110, 0b1000_1110, // BDDD_LBBW
        0b1111_0110, 0b1000_1110, // BDDD_LBBW
        0b1111_0110, 0b1000_1110, // BDDD_LBBW
        0b1111_0110, 0b1000_1110, // BDDD_LBBW
        0b1111_0110, 0b1000_1110, // BDDD_LBBW
        0b1111_0110, 0b1000_1110, // BDDD_LBBW
    } ** Ppu.TileDataInfo.SIZE;
    const tile_data = ppu.vram[0..0x1800];
    for (tile_bytes1, 0..) |b, i| {
        tile_data[i] = b;
    }

    // (0, 0) to (160, 0) is rendered.
    // TileMap[0~20(160/8)] is used.
    // Therefore, TileData[0~20] is used
    // (now, Tile Index in TileData[0] is straight mapped)
    ppu.render_bg();

    for (0..LCD_INFO.width / 8) |i| {
        try expect(ppu.buffer[0 + i * 8] == C.BLACK);
        try expect(ppu.buffer[1 + i * 8] == C.LIGHT_GRAY);
        try expect(ppu.buffer[2 + i * 8] == C.LIGHT_GRAY);
        try expect(ppu.buffer[3 + i * 8] == C.LIGHT_GRAY);
        try expect(ppu.buffer[4 + i * 8] == C.DARK_GRAY);
        try expect(ppu.buffer[5 + i * 8] == C.BLACK);
        try expect(ppu.buffer[6 + i * 8] == C.BLACK);
        try expect(ppu.buffer[7 + i * 8] == C.WHITE);
    }
}

const expect = @import("std").testing.expect;
