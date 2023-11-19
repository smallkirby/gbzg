const Interrupts = @import("interrupts.zig").Interrupts;

pub const Timer = struct {
    /// Incremented every T-cycle. Mapped to FF04.
    /// Upper 16 bits can be read. Any write resets the counter.
    div: u16,
    /// Incremented every $TAC cycles. Mapped to FF05.
    tima: u8,
    /// TIMA overflowed.
    overflow: bool,
    /// Set to TIMA when TIMA overflows. Mapped to FF06.
    tma: u8,
    /// Incremented everytime TAC's 2-th bit is 1.
    /// 0-1 -th bits are used to select the frequency of TIMA incrementation.
    tac: u8,

    pub fn new() @This() {
        return @This(){
            .div = 0,
            .tima = 0,
            .overflow = false,
            .tma = 0,
            .tac = 0,
        };
    }

    pub fn emulate_cycle(self: *@This(), interrupts: *Interrupts) void {
        self.div +%= 4; // 1M-cycle = 4 T-cycles
        const modulo: u16 = switch (self.tac & 0b11) {
            0b01 => 16,
            0b10 => 64,
            0b11 => 256,
            else => 1024,
        };
        if (self.overflow) {
            self.tima = self.tma;
            self.overflow = false;
            interrupts.irq(@intFromEnum(Interrupts.InterruptsEnableBits.TIMER));
        } else if (self.tac & 0b100 != 0 and self.div & (modulo - 1) == 0) {
            const res = @addWithOverflow(self.tima, 1);
            self.tima = res[0];
            self.overflow = res[1] != 0;
        }
    }

    pub fn read(self: @This(), addr: u16) u8 {
        return switch (addr) {
            0xFF04 => @truncate(self.div >> 8),
            0xFF05 => self.tima,
            0xFF06 => self.tma,
            0xFF07 => self.tac | 0b1111_1000,
            else => unreachable,
        };
    }

    pub fn write(self: *@This(), addr: u16, val: u8) void {
        switch (addr) {
            0xFF04 => self.div = 0,
            0xFF05 => if (!self.overflow) {
                self.tima = val;
            },
            0xFF06 => self.tma = val,
            0xFF07 => self.tac = val & 0b111,
            else => unreachable,
        }
    }
};
