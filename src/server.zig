//! This file defines a ZDB server.

const std = @import("std");
const net = std.net;
const gbzg = @import("gbzg.zig");
const GameBoy = gbzg.GameBoy;
const Message = @import("debugger/message.zig").Message;
const Request = @import("debugger/request.zig").Request;
const allocator = gbzg.debugger_allocator;
const c = @cImport({
    @cInclude("sys/epoll.h");
});

const ZdbState = enum {
    Unconnected,
    Connected,
    Continue,
    Step,
};

pub const ZdbSever = struct {
    server: net.StreamServer,
    conn: ?net.StreamServer.Connection = null,
    state: ZdbState = .Unconnected,
    epoll: ?c_int = null,

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
            self.state = .Connected;
            try self.set_epoll(fd);
            return .{
                .stream = std.net.Stream{ .handle = fd },
                .address = accepted_addr,
            };
        } else |err| switch (err) {
            error.WouldBlock => return null,
            else => return err,
        }
    }

    fn set_epoll(self: *@This(), sockfd: c_int) !void {
        if (self.server.sockfd == null) {
            std.log.err("set_poll() is called while the server is not listening", .{});
            unreachable;
        }

        const fd = c.epoll_create(1);
        var event: c.epoll_event = .{
            .events = c.EPOLLIN,
            .data = .{ .fd = sockfd },
        };

        _ = c.epoll_ctl(
            fd,
            c.EPOLL_CTL_ADD,
            sockfd,
            &event,
        );

        self.epoll = fd;
    }

    /// Gracefully close the server.
    pub fn deinit(self: *@This()) void {
        if (self.conn) |conn| {
            conn.stream.close();
        }
        self.server.close();
        self.server.deinit();
    }

    fn handle_request(self: *@This(), req: Request) !void {
        switch (req.id) {
            .Kill => {
                std.log.warn("Killed by zdb. Exiting...", .{});
                unreachable;
            },
            .Continue => {
                self.state = .Continue;
            },
            .Stop => {
                self.state = .Connected;
            },
            else => {},
        }
    }

    pub fn handle_clock(self: *@This(), _: *GameBoy) !void {
        if (self.conn == null) {
            if (try self.accept()) |conn| {
                self.conn = conn;
            } else {
                return;
            }
        }
        const conn = self.conn.?;

        const stream = &conn.stream;
        while (true) {
            var events: [1]c.epoll_event = undefined;
            if (c.epoll_wait(
                self.epoll.?,
                &events[0],
                1,
                0,
            ) == 0) {
                if (self.state == .Continue) break else {
                    std.time.sleep(1000);
                    continue;
                }
            }

            var buf = try allocator.alloc(u8, 0x1000);
            defer allocator.free(buf);

            const n = stream.read(buf[0..]) catch 0;
            if (n == 0) continue;

            const msg = try Message.deserialize(buf[0..n], allocator);
            defer msg.deinit(allocator);
            const req = try Request.deserialize(msg.data);
            try self.handle_request(req);
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
