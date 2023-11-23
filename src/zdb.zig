//! This file defines a ZDB server.

const std = @import("std");
const net = std.net;
const log = std.log;
const allocator = @import("gbzg.zig").debugger_allocator;
const Parser = @import("debugger/parser.zig").CommandParser;
const Message = @import("debugger/message.zig").Message;
const MessageHeader = @import("debugger/message.zig").MessageHeader;

fn loop(stream: net.Stream) !void {
    // input command from user
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    var buf = std.io.bufferedReader(stdin.reader());

    var r = buf.reader();
    var msg_buf: [4096]u8 = undefined;

    while (true) {
        _ = try stdout.write("zdb> ");
        var msg = try r.readUntilDelimiter(&msg_buf, '\n');
        const cmd = Parser.parse_command(msg) catch |err| {
            std.log.err("Error parsing command: {}", .{err});
            continue;
        };

        switch (cmd) {
            .exit => break,
            else => {
                const request = try Parser.get_request(cmd);
                const message = try Message.serialize(request, allocator);
                defer allocator.free(message);
                _ = try stream.write(message);
            },
        }
    }

    std.log.info("Exiting", .{});
}

pub fn main() !void {
    const addr = try net.Address.resolveIp("0.0.0.0", 49494);
    const stream = try net.tcpConnectToAddress(addr);
    defer stream.close();

    log.info("Connected to ZDB server", .{});
    try loop(stream);
}
