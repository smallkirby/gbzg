//! Sixel module.
//! This module has Renderer implementation and Controller implementation.
//! For the controller inpl, it uses epoll to watch stdin.

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
    @cInclude("sys/epoll.h");
});

pub const Sixel = struct {
    sixel_output: ?*sixel.sixel_output_t align(64),
    sixel_dither: ?*sixel.sixel_dither_t align(64),
    sixel_encoder: ?*sixel.sixel_encoder align(64),
    buffer: [LCD_INFO.pixels * 3]u8, // *3 for RGB888
    old_termios: ?c.termios,
    key_watcher: ?std.Thread,
    mutex: std.Thread.Mutex,
    key_buffer: [0x10]?u32 = [_]?u32{null} ** 0x10,

    options: Options,

    pub const SixelErrors = error{
        OutputNewError,
        EncodeError,
        TermionError,
        ThreadError,
    };

    pub fn new(options: Options) !@This() {
        const buffer = try gbzg.default_allocator.alloc([LCD_INFO.pixels * 3]u8, 1);

        var ret = @This(){
            .sixel_output = null,
            .sixel_dither = null,
            .sixel_encoder = null,
            .buffer = buffer[0],
            .old_termios = null,
            .key_watcher = null,
            .mutex = std.Thread.Mutex{},
            .options = options,
        };

        if (!ret.options.no_graphics) {
            try ret.set_terminal_raw();
            try ret.output_new();
            try ret.dither_get();
            try ret.dither_set_pixelformat();
            try ret.create_encoder();
        }

        return ret;
    }

    fn output_new(self: *@This()) SixelErrors!void {
        const status = sixel.sixel_output_new(
            @as(
                [*c]?*sixel.sixel_output_t,
                @ptrCast(&self.sixel_output),
            ),
            sixel_write,
            c.stdout,
            null,
        );

        if (sixel.SIXEL_FAILED(status)) {
            return SixelErrors.OutputNewError;
        }
    }

    fn dither_get(self: *@This()) SixelErrors!void {
        self.sixel_dither = sixel.sixel_dither_get(sixel.SIXEL_BUILTIN_XTERM256);
    }

    fn dither_set_pixelformat(self: *@This()) SixelErrors!void {
        sixel.sixel_dither_set_pixelformat(self.sixel_dither, sixel.SIXEL_PIXELFORMAT_RGB888);
    }

    fn create_encoder(self: *@This()) SixelErrors!void {
        self.sixel_encoder = sixel.sixel_encoder_create();
    }

    pub fn draw(self: *@This(), pixels: []u8) SixelErrors!void {
        if (self.options.no_graphics) {
            return;
        }

        self.scroll_to_top();

        for (0..LCD_INFO.pixels * 3) |i| {
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
        new_temios.c_lflag &= ~@as(c_uint, c.BRKINT);
        new_temios.c_lflag &= ~@as(c_uint, c.ECHO);
        new_temios.c_cc[c.VMIN] = 0;
        new_temios.c_cc[c.VTIME] = 0;

        ret = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &new_temios);
        if (ret < 0) {
            return SixelErrors.TermionError;
        }

        _ = c.printf("\x1B[?25l\x1B"); // hide cursor
        _ = c.printf("\x1B[1B"); // move cursor down by 1
        self.save_cursor_position();
    }

    pub fn get_keys(self: *@This()) []?u32 {
        var keys = [_]?u32{null} ** 0x10;

        if (self.mutex.tryLock() == false) {
            return &.{};
        }
        defer self.mutex.unlock();

        for (0..self.key_buffer.len) |i| {
            if (self.key_buffer[i]) |key| {
                keys[i] = key;
                self.key_buffer[i] = null;
            }
        }

        return &keys;
    }

    fn watch_key(self: *@This()) void {
        var fd = c.epoll_create(5);
        var event: c.epoll_event = .{
            .events = c.EPOLLIN,
            .data = .{
                .fd = c.STDIN_FILENO,
            },
        };

        _ = c.epoll_ctl(
            fd,
            c.EPOLL_CTL_ADD,
            c.STDIN_FILENO,
            @ptrCast(&event),
        );

        while (true) {
            var events: [1]c.epoll_event = undefined;
            var ret = c.epoll_wait(
                fd,
                @ptrCast(&events),
                1,
                0,
            );

            if (ret != 0) {
                var data: u8 = undefined;
                while (c.read(c.STDIN_FILENO, @ptrCast(&data), 1) > 0) {
                    while (self.mutex.tryLock() == false) {
                        std.time.sleep(10);
                    }
                    defer self.mutex.unlock();
                    for (0..self.key_buffer.len) |i| {
                        if (self.key_buffer[i] == null) {
                            self.key_buffer[i] = @as(u32, data);
                            break;
                        }
                    }

                    std.time.sleep(10);
                }
            }
        }
    }

    pub fn start_key_watch(self: *@This()) SixelErrors!void {
        self.key_watcher = std.Thread.spawn(
            .{},
            watch_key,
            .{self},
        ) catch |err| {
            std.log.err("failed to spawn thread: {!}", .{err});
            return SixelErrors.ThreadError;
        };
    }

    pub fn deinit_key_watch(self: *@This()) void {
        if (self.key_watcher) |watcher| {
            watcher.detach();
        }
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
