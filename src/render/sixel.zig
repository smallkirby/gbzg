const std = @import("std");
const gbzg = @import("../gbzg.zig");
const Options = gbzg.Options;
const LCD_INFO = gbzg.LCD_INFO;
const sixel = @cImport({
    @cInclude("sixel/sixel.h");
});
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

pub const Sixel = struct {
    sixel_output: ?*sixel.sixel_output_t align(64),
    sixel_dither: ?*sixel.sixel_dither_t align(64),
    buffer: [LCD_INFO.pixels]u8,
    old_termios: ?c.termios,

    options: Options,

    pub const SixelErrors = error{
        OutputNewError,
        EncodeError,
        TermionError,
    };

    pub fn new(options: Options) !@This() {
        const buffer = try gbzg.default_allocator.alloc([LCD_INFO.pixels]u8, 1);

        var ret = @This(){
            .sixel_output = null,
            .sixel_dither = null,
            .buffer = buffer[0],
            .old_termios = null,
            .options = options,
        };

        if (!ret.options.no_graphics) {
            try ret.set_terminal_raw();
            try ret.output_new();
            try ret.dither_get();
            try ret.dither_set_pixelformat();
        }

        return ret;
    }

    fn output_new(self: *@This()) SixelErrors!void {
        const status = sixel.sixel_output_new(
            @as([*c]?*sixel.sixel_output_t, @ptrCast(&self.sixel_output)),
            sixel_write,
            c.stdout,
            null,
        );

        if (sixel.SIXEL_FAILED(status)) {
            return SixelErrors.OutputNewError;
        }
    }

    fn dither_get(self: *@This()) SixelErrors!void {
        self.sixel_dither = sixel.sixel_dither_get(sixel.SIXEL_BUILTIN_G8);
    }

    fn dither_set_pixelformat(self: *@This()) SixelErrors!void {
        sixel.sixel_dither_set_pixelformat(self.sixel_dither, sixel.SIXEL_PIXELFORMAT_G8);
    }

    pub fn draw(self: *@This(), pixels: []u8) SixelErrors!void {
        if (self.options.no_graphics) {
            return;
        }

        self.scroll_to_top();

        for (0..LCD_INFO.pixels) |i| {
            self.buffer[i] = pixels[i];
        }

        const status = sixel.sixel_encode(
            @ptrCast(&self.buffer),
            LCD_INFO.width,
            LCD_INFO.height,
            0,
            self.sixel_dither,
            @ptrCast(@alignCast(self.sixel_output)),
        );

        if (sixel.SIXEL_FAILED(status)) {
            return SixelErrors.EncodeError;
        }

        _ = c.fflush(c.stdout);
    }

    fn sixel_write(data: [*c]u8, size: c_int, priv: ?*anyopaque) callconv(.C) c_int {
        _ = c.fwrite(data, 1, @intCast(size), @alignCast(@ptrCast(priv)));
        return 0;
    }

    fn get_termios_empty() c.termios {
        return .{
            .c_iflag = 0,
            .c_oflag = 0,
            .c_cflag = 0,
            .c_lflag = 0,
            .c_line = 0,
            .c_ispeed = 0,
            .c_ospeed = 0,
            .c_cc = std.mem.zeroes([32]u8),
        };
    }

    fn set_terminal_raw(self: *@This()) SixelErrors!void {
        var old_termios: c.termios = get_termios_empty();
        var new_temios: c.termios = get_termios_empty();

        var ret = c.tcgetattr(c.STDIN_FILENO, @ptrCast(&old_termios));
        if (ret < 0) {
            return SixelErrors.TermionError;
        }
        self.old_termios = old_termios;

        new_temios = old_termios;
        new_temios.c_lflag &= ~(@as(c_uint, c.BRKINT) | @as(c_uint, c.ICRNL) | @as(c_uint, c.INPCK) | @as(c_uint, c.ISTRIP) | @as(c_uint, c.IXON));
        new_temios.c_lflag &= ~(@as(c_uint, c.ECHO) | @as(c_uint, c.ICANON) | @as(c_uint, c.IEXTEN) | @as(c_uint, c.ISIG));
        new_temios.c_cflag &= ~(@as(c_uint, c.CSIZE) | @as(c_uint, c.PARENB));
        new_temios.c_cflag |= @as(c_uint, c.CS8);
        new_temios.c_oflag &= ~(@as(c_uint, c.OPOST));
        new_temios.c_cc[c.VMIN] = 1;
        new_temios.c_cc[c.VTIME] = 0;

        ret = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &new_temios);
        if (ret < 0) {
            return SixelErrors.TermionError;
        }

        _ = c.printf("\x1B[?25l\x1B"); // hide cursor
        _ = c.printf("\x1B[1B"); // move cursor down by 1
        self.save_cursor_position();
    }

    fn restore_terminal(self: @This()) SixelErrors!void {
        _ = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, @ptrCast(&self.old_termios.?));
        _ = c.printf("\x1B[?25h"); // show cursor
        _ = c.fflush(c.stdout);
    }

    fn save_cursor_position(_: @This()) void {
        _ = c.printf("\x1B[s");
        _ = c.fflush(c.stdout);
    }

    fn restore_cursor_position(_: @This()) void {
        _ = c.printf("\x1B[u");
        _ = c.fflush(c.stdout);
    }

    fn scroll_to_top(_: @This()) void {
        _ = c.printf("\x1B[2J\x1B[H");
        _ = c.fflush(c.stdout);
    }

    pub fn deinit(self: @This()) SixelErrors!void {
        if (!self.options.no_graphics) {
            _ = c.printf("\x1B[1B"); // move cursor down by 1
            try self.restore_terminal();
        }
    }
};
