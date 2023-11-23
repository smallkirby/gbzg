const std = @import("std");
const Request = @import("request.zig").Request;
const Allocator = std.mem.Allocator;

pub const MessgeError = error{
    InvalidMagic,
    AllocationFailed,
};

pub const MessageHeader = packed struct {
    pub const MessageMagic: u32 = 0xDEADBEEF;

    magic: u32,
    size: u32,

    pub fn new(size: usize) @This() {
        return @This(){
            .magic = MessageMagic,
            .size = @truncate(size),
        };
    }

    pub fn from(bytes: []u8) @This() {
        return @bitCast(@as([8]u8, bytes[0..8].*));
    }

    pub fn serialize(self: @This()) [8]u8 {
        const a = @as([4]u8, @bitCast(self.magic));
        const b = @as([4]u8, @bitCast(self.size));
        return a ++ b;
    }
};

pub const Message = struct {
    header: MessageHeader,
    data: []u8,

    pub fn serialize(request: Request, allocator: Allocator) ![]u8 {
        const req_bytes = try request.serialize(allocator);
        defer allocator.free(req_bytes);

        const buf = allocator.alloc(
            u8,
            @sizeOf(MessageHeader) + req_bytes.len,
        ) catch return error.AllocationFailed;
        std.mem.copy(
            u8,
            buf,
            &MessageHeader.new(req_bytes.len).serialize(),
        );
        std.mem.copy(
            u8,
            buf[@sizeOf(MessageHeader)..],
            req_bytes,
        );

        return buf;
    }

    /// Deserialize a message from a byte array.
    /// Returned message must be deinitialized with `deinit()`.
    pub fn deserialize(bytes: []u8, allocator: std.mem.Allocator) MessgeError!@This() {
        const header = MessageHeader.from(bytes);
        if (header.magic != MessageHeader.MessageMagic) {
            return error.InvalidMagic;
        }

        const data = allocator.alloc(u8, header.size) catch return error.AllocationFailed;
        for (0..header.size) |i| {
            data[i] = bytes[@sizeOf(MessageHeader) + i];
        }

        return @This(){
            .header = header,
            .data = data,
        };
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

test "struct MessageHeader" {
    try expect(@sizeOf(MessageHeader) == 8);

    const bytes = [_]u8{ 0xEF, 0xBE, 0xAD, 0xDE, 0x12, 0x34, 0x00, 0x00 };
    const header: MessageHeader = @bitCast(bytes);
    try expect(header.magic == MessageHeader.MessageMagic);
    try expect(header.size == 0x3412);
}

test "new Message" {
    const header = MessageHeader.new(0x40);
    const data = [_]u8{ 0x00, 0x01, 0x02, 0x03 } ** 0x10;
    var bytes = header.serialize() ++ data;
    try expect(bytes.len == 0x48);

    const message = try Message.deserialize(&bytes, std.testing.allocator);
    defer message.deinit(std.testing.allocator);
    try expect(message.header.magic == MessageHeader.MessageMagic);
    try expect(message.header.size == 0x40);
    try expect(std.mem.eql(u8, message.data, &data));
}

const expect = std.testing.expect;
