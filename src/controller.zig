//! This file defines the interface for the Joypad controller.

const Sixel = @import("render/sixel.zig").Sixel;
const std = @import("std");

pub const Controller = union(enum) {
    sixel: *Sixel,

    /// Deinitializes the controller.
    pub fn deinit(self: *@This()) !void {
        return switch (self.*) {
            .sixel => self.sixel.deinit_key_watch(),
        };
    }

    /// Get buffered keys.
    pub fn get_keys(self: *@This()) []?u32 {
        return switch (self.*) {
            .sixel => self.sixel.get_keys(),
        };
    }

    /// Start watching for key presses in the background.
    pub fn start_key_watch(self: *@This()) !void {
        return switch (self.*) {
            .sixel => self.sixel.start_key_watch(),
        };
    }
};
