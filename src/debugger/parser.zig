const commands = @import("command.zig");
const Command = @import("command.zig").Command;
const Request = @import("request.zig").Request;
const std = @import("std");

pub const CommandError = error{
    NotFound,
    NotImplemented,
    InvalidArgument,
};

pub const CommandParser = struct {
    pub fn parse_command(str: []u8) CommandError!Command {
        var iter = std.mem.split(u8, str, " ");

        const s_cmd = iter.next() orelse return error.InvalidArgument;
        const eql = std.mem.eql;

        if (eql(u8, s_cmd, "exit")) {
            return .{ .exit = .{} };
        } else if (eql(u8, s_cmd, "kill")) {
            return .{ .kill = .{} };
        } else if (eql(u8, s_cmd, "cont")) {
            return .{ .cont = .{} };
        } else if (eql(u8, s_cmd, "stop")) {
            return .{ .stop = .{} };
        } else {
            return error.NotFound;
        }
    }

    pub fn get_request(cmd: Command) !Request {
        return switch (cmd) {
            .kill => Request.new(.{ .kill = .{} }),
            .cont => Request.new(.{ .cont = .{} }),
            .stop => Request.new(.{ .stop = .{} }),
            else => unreachable,
        };
    }
};
