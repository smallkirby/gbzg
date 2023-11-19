const std = @import("std");
const gbzg = @import("gbzg.zig");
const Interrupts = @import("interrupts.zig").Interrupts;
const IEB = Interrupts.InterruptsEnableBits;
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
    /// Window Line Position (internal)
    /// Rendering of window can be disabled while a rendering of the screen.
    /// Window's Y position must be incremented only when window is enabled and rendered.
    /// This internal register is used to keep track of window's Y position.
    wly: u8,

    /// TODO
    cycles: u8,

    /// OAM DMA source address (address: 0xFF46)
    oam_dma: ?u16 = null,

    /// VRAM
    vram: []u8,
    /// OAM (Object Attribute Memory)
    oam: [OAM_SIZE]u8,
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
    pub const OAM_SIZE = 0xA0; // 160B

    const COLOR = struct {
        pub const WHITE: u8 = 0xFF;
        pub const LIGHT_GRAY: u8 = 0xAA;
        pub const DARK_GRAY: u8 = 0x55;
        pub const BLACK: u8 = 0x00;
    };

    /// Sprite is 4 bytes data representing a 8x8 or 8x16 pixels object.
    /// OAM contains 40 sprites, while sprite buffer contains 10 sprites.
    /// Sprite is fetched from OAM in OAM Scan Mode,
    /// then rendered in Drawing Mode.
    /// But this emulator renders does them in Drawding Mode.
    const Sprite = packed struct {
        /// Y Position of the sprite (subtract 16)
        y: u8,
        /// X Position of the sprite (subtract 8)
        x: u8,
        /// Tile Index of the sprite
        tile_idx: u8,
        /// Attribute of the sprite
        flags: u8,

        const Flags = struct {
            /// Palette number of the sprite
            pub const PALETTE: u8 = 0b0001_0000;
            /// Flip X
            pub const FLIP_X: u8 = 0b0010_0000;
            /// Flip Y
            pub const FLIP_Y: u8 = 0b0100_0000;
            /// Priority
            pub const PRIORITY: u8 = 0b1000_0000;
        };

        pub fn from_bytes(bytes: [40 * 4]u8) [40]@This() {
            return @bitCast(bytes);
        }

        fn cmp(_: void, a: @This(), b: @This()) bool {
            return a.x < b.x;
        }
    };

    pub fn new() !@This() {
        const vram = try gbzg.ppu_allocator.alloc([VRAM_SIZE]u8, 1);
        const oam = try gbzg.ppu_allocator.alloc([OAM_SIZE]u8, 1);
        const buffer = try gbzg.ppu_allocator.alloc([LCD_INFO.pixels]u8, 1);
        return .{
            .mode = .OamScan,
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
            .wly = 0,
            .cycles = 20,
            .vram = &vram[0],
            .oam = oam[0],
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
            // OAM
            0xFE00...0xFE9F => blk: {
                if (self.mode == .OamScan or self.mode == .Drawing) {
                    // cannot read OAM during OAM Scan Mode or Drawing Mode
                    break :blk 0xFF;
                } else {
                    // cannot read OAM during OAM DMA
                    break :blk if (self.oam_dma) |_| 0xFF else self.oam[addr & 0xFF];
                }
            },
            0xFF40 => self.lcdc,
            0xFF41 => 0b1000_0000 | self.stat | @intFromEnum(self.mode),
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
            // OAM
            0xFE00...0xFE9F => if (self.mode != .OamScan and self.mode != .Drawing) {
                // cannot write OAM during OAM DMA
                if (self.oam_dma == null)
                    self.oam[addr & 0xFF] = val;
            },
            0xFF40 => self.lcdc = val,
            0xFF41 => self.stat = (self.stat & LYC_EQ_LY) | (val & 0b1111_1000),
            0xFF42 => self.scy = val,
            0xFF43 => self.scx = val,
            0xFF44 => {}, // write not allowed
            0xFF45 => self.lyc = val,
            0xFF46 => self.oam_dma = @as(u16, @intCast(val)) << 8,
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
        const r = @as(u8, row) * 2;
        const c = 7 - col;
        const tile_addr = tile_idx << TILE_IDX_TO_ADDR_SHIFT;
        const low = self.vram[(tile_addr | r) & 0x1FFF];
        const high = self.vram[(tile_addr | (r + 1)) & 0x1FFF];
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
        const ret = self.vram[(start_addr + (@as(usize, @intCast(row)) * TileMapInfo.COLS) + col) & 0x3FFF];

        if (self.lcdc & BG_TILE_DATA_ADDRESSING_MODE != 0) {
            return ret;
        } else {
            const reti16 = @as(i16, @intCast(@as(i8, @bitCast(ret)))) + 0x100;
            return @as(u16, @bitCast(reti16));
        }
    }

    /// Reender background of the current line specified by ly.
    /// LCD is 100x144 pixel, while Tile Map has 256x256 pixel.
    /// Therefore, this function renders 160x144 pixels of Tile Map decided by SCX and SCY.
    /// TODO: function name should be changed to `render_bg_line` ?
    fn render_bg(self: *@This(), bg_prio: *[LCD_INFO.width]bool) void {
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

            self.buffer[@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i] = switch ((self.bgp >> ((@as(u3, pixel) * 2))) & 0b11) {
                0 => COLOR.WHITE,
                1 => COLOR.LIGHT_GRAY,
                2 => COLOR.DARK_GRAY,
                3 => COLOR.BLACK,
                else => unreachable,
            };

            bg_prio[i] = pixel != 0;
        }
    }

    /// Render window.
    /// Rendering of window differs from rendering of bg in the following points:
    /// - Window is rendered at (wx - 7, wy) position. (while bg at (0,0))
    /// - Window fetches data from (0, 0) of 256x256 TileMap (while bg from (scx, scy))
    /// - Window is rendered on the top of bg.
    fn render_window(self: *@This(), bg_info: *[LCD_INFO.width]bool) void {
        if (self.lcdc & BG_WINDOW_ENABLE == 0 or self.lcdc & WINDOW_ENABLE == 0 or self.wy > self.ly) {
            return;
        }

        var wly_add: u8 = 0;
        const y = self.wly;
        for (0..LCD_INFO.width) |i| {
            const x_res = @subWithOverflow(@as(u8, @truncate(i)), self.wx -% 7);
            if (x_res[1] != 0) {
                continue;
            }
            wly_add = 1;

            const tile_idx = self.get_tile_idx_from_tile_map(
                @intFromBool(self.lcdc & WINDOW_TILE_MAP != 0),
                y / TileInfo.HEIGHT,
                x_res[0] / TileInfo.WIDTH,
            );

            const pixel = self.get_pixel_from_tile(
                tile_idx,
                @intCast(y % TileInfo.HEIGHT),
                @intCast(x_res[0] % TileInfo.WIDTH),
            );

            self.buffer[@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i] = switch ((self.bgp >> ((@as(u3, pixel) * 2))) & 0b11) {
                0 => COLOR.WHITE,
                1 => COLOR.LIGHT_GRAY,
                2 => COLOR.DARK_GRAY,
                3 => COLOR.BLACK,
                else => unreachable,
            };

            bg_info[i] = pixel != 0;
        }

        self.wly += wly_add;
    }

    fn get_ordered_sprites(self: @This()) [40]Sprite {
        // Get sprites to render
        var sprites_cands = Sprite.from_bytes(self.oam);
        for (0..sprites_cands.len) |i| {
            sprites_cands[i].y -%= 16;
            sprites_cands[i].x -%= 8;
        }

        // Sprites in lower addr in OAM has higher priority.
        var orderd_sprites = sprites_cands;
        for (sprites_cands, 0..) |sprite, i| {
            orderd_sprites[sprites_cands.len - (i + 1)] = sprite;
        }

        // Sprites located left has higher priority.
        std.sort.block(
            Sprite,
            orderd_sprites[0..orderd_sprites.len],
            {},
            Sprite.cmp,
        );

        return orderd_sprites;
    }

    /// Render sprites.
    fn render_sprite(self: *@This(), bg_prio: *[LCD_INFO.width]bool) void {
        if (self.lcdc & SPRITE_ENABLE == 0) {
            return;
        }
        const size: usize = if (self.lcdc & SPRITE_SIZE != 0) 16 else 8;
        const ordered_sprites = self.get_ordered_sprites();

        var rendered: usize = 0;
        var ix: usize = 0;
        while (rendered < 10 and ix < ordered_sprites.len) : (ix += 1) {
            const Flags = Sprite.Flags;
            const sprite = ordered_sprites[ix];
            if (self.ly -% sprite.y >= size) {
                continue;
            }
            rendered += 1;

            const palette = if (sprite.flags & Flags.PALETTE != 0) self.obp1 else self.obp0;
            var tile_idx: usize = @intCast(sprite.tile_idx);
            var row = if (sprite.flags & Flags.FLIP_Y != 0)
                size - 1 - (self.ly -% sprite.y)
            else
                self.ly -% sprite.y;
            if (size == 16) tile_idx &= 0xFE;
            tile_idx += @intFromBool(row >= 8);
            row &= 7;

            for (0..8) |col| {
                const col_flipped = if (sprite.flags & Flags.FLIP_X != 0) 7 - col else col;
                const pixel = self.get_pixel_from_tile(
                    tile_idx,
                    @intCast(row),
                    @intCast(col_flipped),
                );
                const i: usize = @intCast(sprite.x +% col);
                if (i < LCD_INFO.width and pixel > 0) {
                    if (sprite.flags & Flags.PRIORITY != 0 or !bg_prio[i]) {
                        self.buffer[@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i] = switch ((palette >> ((@as(u3, pixel) * 2))) & 0b11) {
                            0 => COLOR.WHITE,
                            1 => COLOR.LIGHT_GRAY,
                            2 => COLOR.DARK_GRAY,
                            3 => COLOR.BLACK,
                            else => unreachable,
                        };
                    }
                }
            }
        }
    }

    fn render(self: *@This()) void {
        var bg_prio = [_]bool{false} ** LCD_INFO.width;

        self.render_bg(&bg_prio);
        self.render_window(&bg_prio);
        self.render_sprite(&bg_prio);
    }

    /// TODO
    fn check_lyc_eq_ly(self: *@This(), intrs: *Interrupts) void {
        if (self.ly == self.lyc) {
            self.stat |= LYC_EQ_LY;
            if (self.stat & LYC_EQ_LY_INT != 0) {
                intrs.irq(@intFromEnum(IEB.STAT));
            }
        } else {
            self.stat &= ~LYC_EQ_LY;
        }
    }

    pub fn oam_dma_emulate_cycle(self: *@This(), val: u8) void {
        if (self.oam_dma) |addr| {
            if (self.mode != .OamScan and self.mode != .Drawing) {
                self.oam[addr & 0xFF] = val;
            }
            self.oam_dma = addr +% 1;
            if (self.oam_dma.? >= 0xA0) {
                self.oam_dma = null;
            }
        }
    }

    /// Emulate single M-cycle.
    /// Return true if VBlank is emitted.
    pub fn emulate_cycle(self: *@This(), intrs: *Interrupts) bool {
        if (self.lcdc & PPU_ENABLE == 0) {
            return false;
        }

        self.cycles -|= 1;
        if (self.cycles > 0) {
            return false; // do nothing until the last cycle
        }

        return switch (self.mode) {
            .HBlank => blk: {
                self.ly += 1;
                if (self.ly < LCD_INFO.height) {
                    self.mode = .OamScan;
                    self.cycles = 20;
                    if (self.stat & OAM_SCAN_INT != 0) {
                        intrs.irq(@intFromEnum(IEB.STAT));
                    }
                } else {
                    self.mode = .VBlank;
                    self.cycles = 114;
                    intrs.irq(@intFromEnum(IEB.VBLANK));
                    if (self.stat & VBLANK_INT != 0) {
                        intrs.irq(@intFromEnum(IEB.STAT));
                    }
                }
                // we need to check LYC=LY coincidence every time we change LY
                self.check_lyc_eq_ly(intrs);
                break :blk false;
            },
            .VBlank => blk: {
                var vblank = false;
                self.ly += 1;
                // Mode1 lasts 10 lines (10 * 114 = 1140 M-cycles)
                if (self.ly == (LCD_INFO.height + 10)) {
                    vblank = true;
                    self.ly = 0;
                    self.wly = 0;
                    self.mode = .OamScan;
                    self.cycles = 20;
                    if (self.stat & OAM_SCAN_INT != 0) {
                        intrs.irq(@intFromEnum(IEB.STAT));
                    }
                } else {
                    self.cycles = 114;
                }
                // we need to check LYC=LY coincidence every time we change LY
                self.check_lyc_eq_ly(intrs);
                break :blk vblank;
            },
            .OamScan => blk: {
                self.mode = .Drawing;
                self.cycles = 43;
                break :blk false;
            },
            .Drawing => blk: {
                self.render();
                self.mode = .HBlank;
                self.cycles = 51;
                if (self.stat & HBLANK_INT != 0) {
                    intrs.irq(@intFromEnum(IEB.STAT));
                }
                break :blk false;
            },
        };
    }
};

test "init PPU" {
    const ppu = try Ppu.new();
    try expect(ppu.mode == .OamScan);
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
    var bg_prio = [_]bool{false} ** LCD_INFO.width;
    ppu.render_bg(&bg_prio);

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

test "sprites init" {
    try expect(@sizeOf(Ppu.Sprite) == 4);

    var ppu = try Ppu.new();
    for (0..Ppu.OAM_SIZE) |i| {
        ppu.oam[i] = 0;
    }
    var sprites = Ppu.Sprite.from_bytes(ppu.oam);

    try expect(sprites.len == 40);
    try expect(sprites[0].y == 0);
    try expect(sprites[0].x == 0);
    try expect(sprites[0].tile_idx == 0);
    try expect(sprites[0].flags == 0);

    for (0..sprites.len) |i| {
        sprites[i].y -%= 16;
        sprites[i].x -%= 8;
    }
    for (sprites) |sprite| {
        try expect(sprite.y == 0xF0);
        try expect(sprite.x == 0xF8);
    }
}

test "sprite ordering" {
    var ppu = try Ppu.new();
    const sprites = [_]Ppu.Sprite{
        .{ .y = 0 + 16, .x = 0 + 8, .tile_idx = 0, .flags = 0 },
        .{ .y = 1 + 16, .x = 1 + 8, .tile_idx = 0, .flags = 0 },
        .{ .y = 2 + 16, .x = 0 + 8, .tile_idx = 0, .flags = 0 },
        .{ .y = 3 + 16, .x = 0 + 8, .tile_idx = 0, .flags = 0 },
        .{ .y = 4 + 16, .x = 3 + 8, .tile_idx = 0, .flags = 0 },
        .{ .y = 5 + 16, .x = 1 + 8, .tile_idx = 0, .flags = 0 },
        .{ .y = 6 + 16, .x = 4 + 8, .tile_idx = 0, .flags = 0 },
        .{ .y = 7 + 16, .x = 0 + 8, .tile_idx = 0, .flags = 0 },
    } ++ [_]Ppu.Sprite{
        .{ .y = 0xFF, .x = 0xFF, .tile_idx = 0, .flags = 0 },
    } ** 32;
    const sprite_bytes: [40 * 4]u8 = @bitCast(sprites);

    // check if from_bytes works correctly
    const temp = Ppu.Sprite.from_bytes(sprite_bytes);
    var ok_from_bytes = true;
    for (0..sprites.len) |i| {
        expect(temp[i].y == sprites[i].y) catch {
            ok_from_bytes = false;
            std.log.err("i={X}, temp[i].y={X}, sprites[i].y={X}", .{
                i,
                temp[i].y,
                sprites[i].y,
            });
        };
    }
    try expect(ok_from_bytes);

    // check if sorting works correctly
    for (0..sprite_bytes.len) |i| {
        ppu.oam[i] = sprite_bytes[i];
    }
    const ordered_sprites = ppu.get_ordered_sprites();
    const expected_sprites = [_]Ppu.Sprite{
        .{ .y = 7, .x = 0, .tile_idx = 0, .flags = 0 },
        .{ .y = 3, .x = 0, .tile_idx = 0, .flags = 0 },
        .{ .y = 2, .x = 0, .tile_idx = 0, .flags = 0 },
        .{ .y = 0, .x = 0, .tile_idx = 0, .flags = 0 },
        .{ .y = 5, .x = 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 1, .x = 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 4, .x = 3, .tile_idx = 0, .flags = 0 },
        .{ .y = 6, .x = 4, .tile_idx = 0, .flags = 0 },
    };
    for (0..expected_sprites.len) |i| {
        expect(ordered_sprites[i].y == expected_sprites[i].y) catch {
            std.log.err("i={X}, ordered_sprites[i].y={X}, expected_sprites[i].y={X}", .{
                i,
                ordered_sprites[i].y,
                expected_sprites[i].y,
            });
        };
    }
}

const expect = @import("std").testing.expect;
