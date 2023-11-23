comptime {
    _ = @import("message.zig");
    _ = @import("request.zig");
    _ = @import("parser.zig");
    _ = @import("command.zig");

    @import("std").testing.refAllDecls(@This());
}
