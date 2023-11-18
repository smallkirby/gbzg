/// Interrupts
pub const Interrupts = struct {
    /// Interrupts Master Enable
    ime: bool = false,
    /// Interrupts Enable Flag
    int_flags: u8,
    /// Interrupts Request Flag
    int_enable: u8,

    pub fn new() @This() {
        return @This(){
            .int_flags = 0,
            .int_enable = 0,
        };
    }
};
