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
    /// Whether this PPU is for GameBoy Color
    is_cgb: bool = false,

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
    /// BCPS (Background Color Palette Specification)
    bcps: u8,
    /// OCPS (Object Color Palette Specification)
    ocps: u8,
    /// VBK (VRAM Bank)
    vbk: u8,

    /// TODO
    cycles: u8,

    /// OAM DMA source address (address: 0xFF46)
    oam_dma: ?u16 = null,
    /// VRAM DMA source (address: 0xFF51-0xFF52)
    hdma_src: u16 = 0,
    /// VRAM DMA destination (address: 0xFF53-0xFF54)
    hdma_dst: u16 = 0,
    /// HBlank DMA (address: 0xFF55, 7-th bit == 1)
    hblank_dma: ?struct {
        src: u16 = 0,
        dst: u16 = 0,
        len: u16 = 0,
    } = null,
    /// General Purpose DMA (address: 0xFF55, 7-th bit == 0)
    general_purpose_dma: ?struct {
        src: u16 = 0,
        dst: u16 = 0,
        len: u16 = 0,
    } = null,

    /// VRAM (Switchable Bank 0 for CGB)
    /// cf: https://gbdev.io/pandocs/CGB_Registers.html#vram-banks
    vram1: []u8,
    /// VRAM (Switchable Bank 1 for CGB)
    vram2: []u8,
    /// bg and window palette memory
    bg_palette_mem: []u8,
    /// window palette memory
    sprite_palette_mem: []u8,
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

    pub const Priority = std.meta.Tuple(&.{ bool, bool });

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
            /// Color palette (CGB only)
            pub const COLOR_PALETTE: u8 = 0b0000_0111;
            /// VRAM Bank
            pub const VRAM_BANK: u8 = 0b0000_1000;
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
            return a.x > b.x;
        }
    };

    const BGAttribute = packed struct {
        /// Which of BGP0~7 to use
        color_palette: u3,
        /// VRAM Bank
        vram_bank: u1,
        // Unused
        _unused: u1,
        /// Flip X
        flip_x: bool,
        /// Flip Y
        flip_y: bool,
        /// Priority
        prio: bool,
    };

    pub fn new() !@This() {
        const vram1 = try gbzg.ppu_allocator.alloc([VRAM_SIZE]u8, 1);
        const vram2 = try gbzg.ppu_allocator.alloc([VRAM_SIZE]u8, 1);
        const oam = try gbzg.ppu_allocator.alloc([OAM_SIZE]u8, 1);
        const buffer = try gbzg.ppu_allocator.alloc([LCD_INFO.pixels * 4]u8, 1); // *4 for RGBA
        const bg_palette_mem = try gbzg.ppu_allocator.alloc([0x40]u8, 1);
        const sprite_palette_mem = try gbzg.ppu_allocator.alloc([0x40]u8, 1);
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
            .bcps = 0,
            .ocps = 0,
            .vbk = 0,
            .cycles = 20,
            .vram1 = &vram1[0],
            .vram2 = &vram2[0],
            .bg_palette_mem = &bg_palette_mem[0],
            .sprite_palette_mem = &sprite_palette_mem[0],
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
                    break :blk if (self.vbk & 0b1 == 0)
                        self.vram1[addr & 0x1FFF]
                    else
                        self.vram2[addr & 0x1FFF];
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
            0xFF4F => self.vbk | 0b1111_1110,
            0xFF51...0xFF54 => unreachable, // HDMA 1-4 is write-only
            0xFF55 => if (self.hblank_dma) |hd|
                0b1000_0000 | @as(u8, @truncate(hd.len / 10 - 1))
            else
                0xFF,
            0xFF68 => self.bcps,
            // BCPD/BGPD
            0xFF69 => if (self.mode == .Drawing) 0xFF else self.bg_palette_mem[self.bcps & 0x3F],
            0xFF6A => self.ocps,
            // OCPD/OBPD
            0xFF6B => if (self.mode == .Drawing) 0xFF else self.sprite_palette_mem[self.ocps & 0x3F],
            else => unreachable,
        };
    }

    pub fn write(self: *@This(), addr: u16, val: u8) void {
        switch (addr) {
            0x8000...0x9FFF => if (self.mode != .Drawing) { // cannot write VRAM during Drawing Mode
                if (self.vbk & 0b1 == 0)
                    self.vram1[addr & 0x1FFF] = val
                else
                    self.vram2[addr & 0x1FFF] = val;
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
            0xFF4F => self.vbk = val & 0b1,
            0xFF51 => self.hdma_src = (self.hdma_src & 0x00F0) | @as(u16, val),
            0xFF52 => self.hdma_src = (self.hdma_src & 0xFF00) | (@as(u16, val) << 8),
            0xFF53 => self.hdma_dst = (self.hdma_dst & 0x00F0) | @as(u16, val),
            0xFF54 => self.hdma_dst = (self.hdma_dst & 0xFF00) | (@as(u16, val) << 8),
            // cf: https://gbdev.io/pandocs/CGB_Registers.html#ff55--hdma5-cgb-mode-only-vram-dma-lengthmodestart
            0xFF55 => if (val & 0b1000_0000 == 0) {
                // General Purpose DMA
                self.general_purpose_dma = .{
                    .src = self.hdma_src,
                    .dst = self.hdma_dst,
                    .len = @as(u16, val & 0b0111_1111) * 0x10 + 1,
                };
            } else {
                // HBlank DMA
                self.hblank_dma = .{
                    .src = self.hdma_src,
                    .dst = self.hdma_dst,
                    .len = @as(u16, val & 0b0111_1111) * 0x10 + 1,
                };
            },
            0xFF68 => self.bcps = val,
            // BCPD/BGPD
            0xFF69 => if (self.mode != .Drawing) {
                self.bg_palette_mem[self.bcps & 0x3F] = val;
                if (self.bcps & 0x80 != 0) {
                    self.bcps = (self.bcps & 0xC0) | ((self.bcps + 1) & 0x3F);
                }
            },
            0xFF6A => self.ocps = val,
            // OCPD/OBPD
            0xFF6B => if (self.mode != .Drawing) {
                self.sprite_palette_mem[self.ocps & 0x3F] = val;
                if (self.ocps & 0x80 != 0) {
                    self.ocps = (self.ocps & 0xC0) | ((self.ocps + 1) & 0x3F);
                }
            },
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
    fn get_pixel_from_tile(
        self: @This(),
        tile_idx: usize,
        row: u3,
        col: u3,
        vram_bank: u2,
    ) u2 {
        const vram = if (vram_bank == 0) self.vram1 else self.vram2;
        const r = @as(u8, row) * 2;
        const c = 7 - col;
        const tile_addr = tile_idx << TILE_IDX_TO_ADDR_SHIFT;
        const low = vram[(tile_addr | r) & 0x1FFF];
        const high = vram[(tile_addr | (r + 1)) & 0x1FFF];
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
        const ret = self.vram1[(start_addr + (@as(usize, @intCast(row)) * TileMapInfo.COLS) + col) & 0x3FFF];

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
    fn render_bg(self: *@This(), bg_prio: *[LCD_INFO.width]Priority) void {
        if (self.lcdc & BG_WINDOW_ENABLE == 0) {
            return;
        }

        const y = self.ly +% self.scy;
        for (0..LCD_INFO.width) |i| {
            const x: u8 = @as(u8, @truncate(i)) +% self.scx;
            const tile_idx = self.get_tile_idx_from_tile_map(
                @intFromBool((self.lcdc & BG_TILE_MAP) != 0),
                y / TileInfo.HEIGHT,
                x / TileInfo.WIDTH,
            );

            const attr = self.get_bg_attr(
                @intFromBool((self.lcdc & BG_TILE_MAP) != 0),
                y / TileInfo.HEIGHT,
                x / TileInfo.WIDTH,
            );
            const row: u8 = if (attr) |a| b: {
                if (a.flip_y) {
                    break :b TileInfo.HEIGHT - 1 - (y % TileInfo.HEIGHT);
                } else {
                    break :b y % TileInfo.HEIGHT;
                }
            } else y % TileInfo.HEIGHT;
            const col: u8 = if (attr) |a| b: {
                if (a.flip_x) {
                    break :b TileInfo.WIDTH - 1 - (x % TileInfo.WIDTH);
                } else {
                    break :b x % TileInfo.WIDTH;
                }
            } else x % TileInfo.WIDTH;
            const bank = if (attr) |a| @intFromBool(a.vram_bank != 0) else 0;

            const pixel = self.get_pixel_from_tile(
                tile_idx,
                @intCast(row),
                @intCast(col),
                bank,
            );
            bg_prio[i][1] = pixel != 0;

            if (self.is_cgb) {
                const colors = self.get_color_from_palette_mem(
                    self.bg_palette_mem,
                    attr.?.color_palette,
                    pixel,
                );
                for (colors, 0..) |color, j| {
                    self.buffer[(@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i) * 4 + j] = color * 8 | color / 4;
                }
            } else {
                self.buffer[@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i] = switch ((self.bgp >> ((@as(u3, pixel) * 2))) & 0b11) {
                    0 => COLOR.WHITE,
                    1 => COLOR.LIGHT_GRAY,
                    2 => COLOR.DARK_GRAY,
                    3 => COLOR.BLACK,
                    else => unreachable,
                };
            }
        }
    }

    /// Render window.
    /// Rendering of window differs from rendering of bg in the following points:
    /// - Window is rendered at (wx - 7, wy) position. (while bg at (0,0))
    /// - Window fetches data from (0, 0) of 256x256 TileMap (while bg from (scx, scy))
    /// - Window is rendered on the top of bg.
    fn render_window(self: *@This(), bg_prio: *[LCD_INFO.width]Priority) void {
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

            const attr = self.get_bg_attr(
                @intFromBool((self.lcdc & BG_TILE_MAP) != 0),
                y / TileInfo.HEIGHT,
                x_res[0] / TileInfo.WIDTH,
            );
            const row: u8 = if (attr) |a| b: {
                if (a.flip_y) {
                    break :b TileInfo.HEIGHT - 1 - (y % TileInfo.HEIGHT);
                } else {
                    break :b y % TileInfo.HEIGHT;
                }
            } else y % TileInfo.HEIGHT;
            const col: u8 = if (attr) |a| b: {
                if (a.flip_x) {
                    break :b TileInfo.WIDTH - 1 - (x_res[0] % TileInfo.WIDTH);
                } else {
                    break :b x_res[0] % TileInfo.WIDTH;
                }
            } else x_res[0] % TileInfo.WIDTH;
            const bank = if (attr) |a| @intFromBool(a.vram_bank != 0) else 0;

            const pixel = self.get_pixel_from_tile(
                tile_idx,
                @intCast(row),
                @intCast(col),
                bank,
            );
            bg_prio[i][1] = pixel != 0;

            if (self.is_cgb) {
                const colors = self.get_color_from_palette_mem(
                    self.bg_palette_mem,
                    attr.?.color_palette,
                    pixel,
                );
                for (colors, 0..) |color, j| {
                    self.buffer[(@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i) * 4 + j] = color * 8 | color / 4;
                }
            } else {
                self.buffer[@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i] = switch ((self.bgp >> ((@as(u3, pixel) * 2))) & 0b11) {
                    0 => COLOR.WHITE,
                    1 => COLOR.LIGHT_GRAY,
                    2 => COLOR.DARK_GRAY,
                    3 => COLOR.BLACK,
                    else => unreachable,
                };
            }
        }

        self.wly += wly_add;
    }

    fn get_ordered_sprites(self: @This()) ![]Sprite {
        const size: usize = if (self.lcdc & SPRITE_SIZE != 0) 16 else 8;

        // Get sprites to render
        var sprites_cands = Sprite.from_bytes(self.oam);
        for (0..sprites_cands.len) |i| {
            sprites_cands[i].y -%= 16;
            sprites_cands[i].x -%= 8;
        }

        var filled_num: usize = 0;
        var first_cands: [10]?Sprite = [_]?Sprite{null} ** 10;
        for (sprites_cands) |sprite| {
            if (self.ly -% sprite.y < size) {
                first_cands[filled_num] = sprite;
                filled_num += 1;
            }
            if (filled_num == 10) {
                break;
            }
        }
        if (filled_num == 0) {
            return &.{};
        }

        const ordered = try gbzg.default_allocator.alloc(Sprite, filled_num);

        // Sprites in lower addr in OAM has higher priority.
        for (0..filled_num) |i| {
            ordered[filled_num - (i + 1)] = first_cands[i].?;
        }

        // Sprites located left has higher priority.
        std.sort.block(
            Sprite,
            ordered,
            {},
            Sprite.cmp,
        );

        return ordered;
    }

    /// Render sprites.
    fn render_sprite(self: *@This(), bg_prio: *[LCD_INFO.width]Priority) void {
        if (self.lcdc & SPRITE_ENABLE == 0) {
            return;
        }
        const size: usize = if (self.lcdc & SPRITE_SIZE != 0) 16 else 8;
        const ordered_sprites = self.get_ordered_sprites() catch {
            unreachable;
        };
        defer gbzg.default_allocator.free(ordered_sprites);

        for (ordered_sprites) |sprite| {
            const Flags = Sprite.Flags;

            const palette: u8 = if (self.is_cgb) b: {
                break :b @truncate(sprite.flags);
            } else b: {
                break :b if (sprite.flags & Flags.PALETTE != 0) self.obp1 else self.obp0;
            };
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
                    @intFromBool(sprite.flags & Flags.VRAM_BANK != 0 and self.is_cgb),
                );
                const i: usize = @intCast(sprite.x +% col);
                const flg =
                    if (self.is_cgb)
                    (self.lcdc & BG_WINDOW_ENABLE == 0) and
                        (sprite.flags & Flags.PRIORITY == 0 and !bg_prio[i][0]) and
                        bg_prio[i][1]
                else
                    sprite.flags & Flags.PRIORITY == 0 or !bg_prio[i][1];

                if (i < LCD_INFO.width and pixel != 0 and flg) {
                    if (self.is_cgb) {
                        const colors = self.get_color_from_palette_mem(
                            self.sprite_palette_mem,
                            @intCast(palette),
                            pixel,
                        );
                        for (colors, 0..) |color, j| {
                            self.buffer[(@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i) * 4 + j] = color * 8 | color / 4;
                        }
                    } else {
                        self.buffer[@as(usize, LCD_INFO.width) *| @as(usize, self.ly) + i] =
                            switch ((@as(u8, palette) >> ((@as(u3, pixel) * 2))) & 0b11) {
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
        var bg_prio = [_]Priority{.{ false, false }} ** LCD_INFO.width;

        self.render_bg(&bg_prio);
        self.render_window(&bg_prio);
        self.render_sprite(&bg_prio);
    }

    /// Get bg attribute from CGB additionnal 32x32 bytes map in VRAM Bank 1.
    fn get_bg_attr(self: @This(), tile_map: u1, row: u8, col: u8) ?BGAttribute {
        if (self.is_cgb == false) {
            return null;
        }

        const start_addr = if (tile_map == 0)
            TileMapInfo.AddrOne
        else
            TileMapInfo.AddrTwo;
        return @bitCast(self.vram2[@as(u14, @truncate(start_addr + (@as(usize, @intCast(row)) * TileMapInfo.COLS) + col))]);
    }

    /// Get RGB color from specified palette. (CGB only)
    fn get_color_from_palette_mem(
        _: @This(),
        palette_mem: []u8,
        palette: u3,
        pixel: u8,
    ) [4]u8 {
        const rgb555 =
            @as(u16, palette_mem[
            @as(usize, palette) * 8 + @as(usize, pixel) * 2
        ]) |
            @as(u16, palette_mem[
            @as(usize, palette) * 8 + @as(usize, pixel) * 2 + 1
        ]);

        return [4]u8{
            @truncate(rgb555 & 0b0001_1111),
            @truncate((rgb555 >> 5) & 0b0001_1111),
            @truncate((rgb555 >> 10) & 0b0001_1111),
            0xFF,
        };
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
    ppu.vram1[0] = 0b1111_0110; // i0,r0,low
    ppu.vram1[1] = 0b1000_1111; // i0,r0,high
    ppu.vram1[18] = 0b1111_0110; // i1,r1,low
    ppu.vram1[19] = 0b1000_1111; // i1,r1,high

    try expect(ppu.get_pixel_from_tile(0, 0, 0, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(0, 0, 1, 0) == 0b01);
    try expect(ppu.get_pixel_from_tile(0, 0, 2, 0) == 0b01);
    try expect(ppu.get_pixel_from_tile(0, 0, 3, 0) == 0b01);
    try expect(ppu.get_pixel_from_tile(0, 0, 4, 0) == 0b10);
    try expect(ppu.get_pixel_from_tile(0, 0, 5, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(0, 0, 6, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(0, 0, 7, 0) == 0b10);

    try expect(ppu.get_pixel_from_tile(1, 1, 0, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(1, 1, 1, 0) == 0b01);
    try expect(ppu.get_pixel_from_tile(1, 1, 2, 0) == 0b01);
    try expect(ppu.get_pixel_from_tile(1, 1, 3, 0) == 0b01);
    try expect(ppu.get_pixel_from_tile(1, 1, 4, 0) == 0b10);
    try expect(ppu.get_pixel_from_tile(1, 1, 5, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(1, 1, 6, 0) == 0b11);
    try expect(ppu.get_pixel_from_tile(1, 1, 7, 0) == 0b10);
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
    const tile_map1 = ppu.vram1[TileMapInfo.AddrOne..(TileMapInfo.AddrOne + TileMapInfo.SIZE)];
    const tile_map2 = ppu.vram1[TileMapInfo.AddrTwo..(TileMapInfo.AddrTwo + TileMapInfo.SIZE)];
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
    const tile_map = ppu.vram1[TileMapInfo.AddrOne..(TileMapInfo.AddrOne + TileMapInfo.SIZE)];
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
    const tile_data = ppu.vram1[0..0x1800];
    for (tile_bytes1, 0..) |b, i| {
        tile_data[i] = b;
    }

    // (0, 0) to (160, 0) is rendered.
    // TileMap[0~20(160/8)] is used.
    // Therefore, TileData[0~20] is used
    // (now, Tile Index in TileData[0] is straight mapped)
    var bg_prio = [_]Ppu.Priority{.{ false, false }} ** LCD_INFO.width;
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
    ppu.ly = 8;
    const sprites = [_]Ppu.Sprite{
        .{ .y = 1 + 16, .x = 0 + 8 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 2 + 16, .x = 1 + 8 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 3 + 16, .x = 0 + 8 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 4 + 16, .x = 0 + 8 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 5 + 16, .x = 3 + 8 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 6 + 16, .x = 1 + 8 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 7 + 16, .x = 4 + 8 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 8 + 16, .x = 0 + 8 + 1, .tile_idx = 0, .flags = 0 },
    } ++ [_]Ppu.Sprite{
        .{ .y = 16, .x = 0x8, .tile_idx = 0, .flags = 0 },
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
    const ordered_sprites = try ppu.get_ordered_sprites();
    const expected_sprites = [_]Ppu.Sprite{
        .{ .y = 7, .x = 4 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 5, .x = 3 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 6, .x = 1 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 2, .x = 1 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 8, .x = 0 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 4, .x = 0 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 3, .x = 0 + 1, .tile_idx = 0, .flags = 0 },
        .{ .y = 1, .x = 0 + 1, .tile_idx = 0, .flags = 0 },
    };
    var ok_ordering = true;
    for (0..expected_sprites.len) |i| {
        expect(ordered_sprites[i].y == expected_sprites[i].y) catch {
            std.log.err("i={X}, ordered_sprites[i].y={X}, expected_sprites[i].y={X}", .{
                i,
                ordered_sprites[i].y,
                expected_sprites[i].y,
            });
            ok_ordering = false;
        };
    }
    try expect(ok_ordering);
}

const expect = @import("std").testing.expect;
