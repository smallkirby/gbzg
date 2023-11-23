const std = @import("std");
const Interrupts = @import("interrupts.zig").Interrupts;
const IEB = Interrupts.InterruptsEnableBits;

pub const Joypad = struct {
    mode: u8 = 0,
    action: u8 = 0xFF,
    direction: u8 = 0xFF,

    pub fn new() @This() {
        return @This(){};
    }

    pub fn read(self: @This()) u8 {
        var ret: u8 = 0b1100_1111 | self.mode;
        if (self.mode & 0b0001_0000 != 0) {
            ret &= self.direction;
        }
        if (self.mode & 0b0010_0000 != 0) {
            ret &= self.action;
        }
        return ret;
    }

    pub fn write(self: *@This(), val: u8) void {
        self.mode = val & 0b0011_0000;
    }

    pub fn button_pressed(self: *@This(), intrs: *Interrupts, button: Button) void {
        self.direction &= ~button.as_direction();
        self.action &= ~button.as_action();
        intrs.irq(@intFromEnum(IEB.JOYPAD));
    }

    pub fn button_released(self: *@This(), button: Button) void {
        self.direction |= button.as_direction();
        self.action |= button.as_action();
    }
};

pub const Button = enum(u8) {
    Down,
    Up,
    Left,
    Right,
    Start,
    Select,
    A,
    B,

    pub fn as_direction(self: @This()) u8 {
        return switch (self) {
            .Down => 0b1000,
            .Up => 0b0100,
            .Left => 0b0010,
            .Right => 0b0001,
            else => 0,
        };
    }

    pub fn as_action(self: @This()) u8 {
        return switch (self) {
            .Start => 0b1000,
            .Select => 0b0100,
            .B => 0b0010,
            .A => 0b0001,
            else => 0,
        };
    }
};

test "button press" {
    var joypad = Joypad.new();
    var intrs = Interrupts.new();

    joypad.write(0b0010_0000);
    joypad.button_pressed(&intrs, Button.A);
    joypad.button_pressed(&intrs, Button.B);
    try expect(joypad.read() == 0b1110_1100);

    joypad.button_released(Button.A);
    try expect(joypad.read() == 0b1110_1101);
}

const expect = std.testing.expect;
