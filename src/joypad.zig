const std = @import("std");
const Interrupts = @import("interrupts.zig").Interrupts;
const IEB = Interrupts.InterruptsEnableBits;

pub const Joypad = struct {
    register: JoyRegister,

    /// Joypad register
    const JoyRegister = packed struct {
        /// Set to 0 on A button pressed in ActionButton mode, or Right button in DirectionButton mode
        a: u1,
        /// Set to 0 on B button pressed in ActionButton mode, or Left button in DirectionButton mode
        b: u1,
        /// Set to 0 on Select button pressed in ActionButton mode, or Up button in DirectionButton mode
        select: u1,
        /// Set to 0 on Start button pressed in ActionButton mode, or Down button in DirectionButton mode
        start: u1,
        /// If set, DirectionButton mode is enabled.
        direction_enabled: u1,
        /// If set, ActionButton mode is enabled.
        action_enabled: u1,
        /// Unused (always 1)
        _unused: u2 = 0b11,

        fn val(self: @This()) u8 {
            return @as(u8, @bitCast(self));
        }

        pub fn new() @This() {
            return @This(){
                .a = 1,
                .b = 1,
                .select = 1,
                .start = 1,
                .direction_enabled = 1,
                .action_enabled = 1,
            };
        }

        pub fn set(self: *@This(), button: Button) void {
            switch (button) {
                .Down => self.a = 1,
                .Up => self.b = 1,
                .Left => self.select = 1,
                .Right => self.start = 1,
                .Start => self.start = 1,
                .Select => self.select = 1,
                .A => self.a = 1,
                .B => self.b = 1,
            }
        }

        pub fn unset(self: *@This(), button: Button) void {
            switch (button) {
                .Down => self.a = 0,
                .Up => self.b = 0,
                .Left => self.select = 0,
                .Right => self.start = 0,
                .Start => self.start = 0,
                .Select => self.select = 0,
                .A => self.a = 0,
                .B => self.b = 0,
            }
        }
    };

    pub fn new() @This() {
        return @This(){
            .register = JoyRegister.new(),
        };
    }

    pub fn read(self: @This()) u8 {
        return self.register.val();
    }

    pub fn write(self: *@This(), val: u8) void {
        self.register = val & 0b0011_0000;
    }

    pub fn button_pressed(self: *@This(), intrs: *Interrupts, button: Button) void {
        self.register.unset(button);
        intrs.irq(@intFromEnum(IEB.JOYPAD));
    }

    pub fn button_released(self: *@This(), button: Button) void {
        self.register.set(button);
    }
};

pub const Button = enum {
    Down,
    Up,
    Left,
    Right,
    Start,
    Select,
    A,
    B,
};

test "struct JoyRegister" {
    try expect(@sizeOf(Joypad.JoyRegister) == 1);

    const val = 0b1110_1101;
    const reg: Joypad.JoyRegister = @bitCast(@as(u8, val));

    try expect(reg.a == 1);
    try expect(reg.b == 0);
    try expect(reg.select == 1);
    try expect(reg.start == 1);
    try expect(reg.direction_enabled == 0);
    try expect(reg.action_enabled == 1);
    try expect(reg._unused == 0b11);
}

test "button press" {
    var joypad = Joypad.new();
    var intrs = Interrupts.new();

    joypad.button_pressed(&intrs, Button.A);
    joypad.button_pressed(&intrs, Button.B);
    try expect(joypad.read() == 0b1111_1100);

    joypad.button_released(Button.A);
    try expect(joypad.read() == 0b1111_1101);
}

const expect = std.testing.expect;
