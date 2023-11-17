const Sixel = @import("render/sixel.zig").Sixel;
const LCD_INFO = @import("gbzg.zig").LCD_INFO;

pub const Renderer = union(enum) {
    sixel: Sixel,
};

pub const LCD = struct {
    renderer: Renderer,

    pub fn new(renderer: Renderer) !@This() {
        return .{
            .renderer = renderer,
        };
    }

    pub fn deinit(self: @This()) !void {
        switch (self.renderer) {
            .sixel => try self.renderer.sixel.deinit(),
        }
    }

    pub fn draw(self: *@This(), pixels: []u8) !void {
        switch (self.renderer) {
            .sixel => {
                try self.renderer.sixel.draw(pixels);
            },
        }
    }
};
