const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const default_allocator = gpa.allocator();

pub const hram_allocator = default_allocator;
pub const wram_allocator = default_allocator;
pub const ppu_allocator = default_allocator;

pub const LCD_INFO = struct {
    pub const width: u8 = 160;
    pub const height: u8 = 144;
    pub const pixels: usize = @as(usize, width) * @as(usize, height);
};
