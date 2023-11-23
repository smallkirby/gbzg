//! This file defines a ZDB server.

const std = @import("std");
const net = std.net;
const gbzg = @import("gbzg.zig");
const allocator = gbzg.debugger_allocator;

pub const ZdbSever = struct {
    server: net.StreamServer,

    pub fn new() !@This() {
        const opt = net.StreamServer.Options{
            .reuse_address = true,
            .reuse_port = true,
        };
        var server = net.StreamServer.init(opt);

        return @This(){
            .server = server,
        };
    }

    /// Listen on the given host and port.
    /// HACK: Zig 0.11.0 does not support non-blocking std.net.listen, so we have to use `std.os.listen` directly.
    /// HACK: Non-blocking std.net.listen is already merged into master, so we can remove this hack once new Zig is released.
    pub fn listen(self: *@This(), host: [:0]const u8, port: u16) !void {
        if (self.server.sockfd != null) return;

        const addr = try net.Address.resolveIp(host, port);
        const flags = std.os.SOCK.NONBLOCK | std.os.SOCK.CLOEXEC | std.os.SOCK.STREAM;
        const proto = std.os.IPPROTO.TCP;
        const sockfd = try std.os.socket(addr.any.family, flags, proto);
        self.server.sockfd = sockfd;
        errdefer {
            std.os.closeSocket(sockfd);
            self.server.sockfd = null;
        }

        try std.os.setsockopt(
            sockfd,
            std.os.SOL.SOCKET,
            std.os.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );
        if (@hasDecl(std.os.SO, "REUSEPORT")) {
            try std.os.setsockopt(
                sockfd,
                std.os.SOL.SOCKET,
                std.os.SO.REUSEPORT,
                &std.mem.toBytes(@as(c_int, 1)),
            );
        }

        var socklen = addr.getOsSockLen();
        try std.os.bind(sockfd, &addr.any, socklen);
        try std.os.listen(sockfd, self.server.kernel_backlog);
        try std.os.getsockname(sockfd, &self.server.listen_address.any, &socklen);
    }

    /// Try to accept a connection.
    /// Return null if no connection is available.
    /// HACK: Zig 0.11.0 std.net does not allow non-blocking socket and EAGAIN leads to unreachable.
    /// HACK: Non-blocking accept is already merged into master, so we can remove this hack once new Zig is released.
    pub fn accept(self: *@This()) !?net.StreamServer.Connection {
        if (self.server.sockfd == null) {
            std.log.err("accept() is called while the server is not listening", .{});
            unreachable;
        }

        var accepted_addr: std.net.Address = undefined;
        var addr_len: std.os.socklen_t = @sizeOf(std.net.Address);
        const res = std.os.accept(
            self.server.sockfd.?,
            &accepted_addr.any,
            &addr_len,
            std.os.SOCK.CLOEXEC,
        );
        if (res) |fd| {
            return .{
                .stream = std.net.Stream{ .handle = fd },
                .address = accepted_addr,
            };
        } else |err| switch (err) {
            error.WouldBlock => return null,
            else => return err,
        }
    }

    /// Gracefully close the server.
    pub fn deinit(self: *@This()) void {
        self.server.close();
        self.server.deinit();
    }

    fn handle_connection(_: *@This(), conn: net.StreamServer.Connection) !void {
        var buf = try allocator.alloc(u8, 0x1000);
        defer allocator.free(buf);

        const stream = &conn.stream;
        defer stream.close();

        while (true) {
            @memset(buf, 0);
            const n = try stream.read(buf[0..]);
            if (n == 0) {
                break;
            }
            // XXX: impl event handler here
            std.log.info("Read {} bytes", .{n});
            std.log.info("Received: {s}", .{buf});
        }
    }
};

pub fn main() !void {
    var server = try ZdbSever.new();
    try server.listen("0.0.0.0", 49494);
    while (true) {
        const res = try server.accept(false);
        if (res) |conn| {
            try server.handle_connection(conn);
            break;
        }
        std.time.sleep(100);
    }
}
