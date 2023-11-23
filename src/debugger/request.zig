const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Request = struct {
    pub const IDs = enum(u64) {
        Continue,
        Stop,
        Break,
        Kill,
    };
    const RequestData = union(enum) {
        cont: Continue,
        stop: Stop,
        br: Break,
        kill: Kill,
    };

    id: IDs,
    data: RequestData,
    size: usize,

    pub fn new(data: RequestData) @This() {
        const id: IDs = switch (data) {
            .cont => .Continue,
            .stop => .Stop,
            .br => .Break,
            .kill => .Kill,
        };
        const size: usize = switch (data) {
            .cont => @sizeOf(Continue),
            .stop => @sizeOf(Stop),
            .br => @sizeOf(Break),
            .kill => @sizeOf(Kill),
        };
        return @This(){
            .id = id,
            .data = data,
            .size = size,
        };
    }

    /// Serializes the request into a byte slice.
    /// The returned data must be freed by the caller.
    pub fn serialize(self: @This(), allocator: Allocator) ![]u8 {
        var buf = try allocator.alloc(u8, self.size + @sizeOf(IDs));
        var data_slice = buf[@sizeOf(IDs)..];
        const id: u64 = @intFromEnum(self.id);

        std.mem.writeIntNative(u64, buf[0..8], id);

        _ = try switch (self.data) {
            .cont => |d| d.serialize(data_slice),
            .stop => |d| d.serialize(data_slice),
            .br => |d| d.serialize(data_slice),
            .kill => |d| d.serialize(data_slice),
        };

        return buf;
    }

    pub fn deserialize(buf: []u8) !@This() {
        const id: IDs = @as(IDs, @enumFromInt(std.mem.readIntNative(u64, buf[0..8])));
        const b = buf[@sizeOf(IDs)..];
        const data: RequestData = switch (id) {
            .Continue => .{ .cont = try Continue.deserialize(b) },
            .Stop => .{ .stop = try Stop.deserialize(b) },
            .Break => .{ .br = try Break.deserialize(b) },
            .Kill => .{ .kill = try Kill.deserialize(b) },
        };
        return @This(){
            .id = id,
            .data = data,
            .size = buf.len,
        };
    }
};

pub const Continue = packed struct {
    pub fn new() @This() {
        return @This(){};
    }

    pub fn serialize(_: @This(), _: []u8) !usize {
        return 0;
    }

    pub fn deserialize(_: []u8) !@This() {
        return @This(){};
    }
};

pub const Stop = packed struct {
    pub fn new() @This() {
        return @This(){};
    }

    pub fn serialize(_: @This(), _: []u8) !usize {
        return 0;
    }

    pub fn deserialize(_: []u8) !@This() {
        return @This(){};
    }
};

pub const Break = packed struct {
    addr: u32,

    pub fn new(addr: u32) @This() {
        return @This(){
            .addr = addr,
        };
    }

    pub fn serialize(self: @This(), buf: []u8) usize {
        std.mem.writeIntNative(u32, buf[0..4], self.addr);
        return @sizeOf(@This());
    }

    pub fn deserialize(buf: []u8) !@This() {
        const addr = std.mem.readIntNative(u32, buf[0..4]);
        return @This(){
            .addr = addr,
        };
    }
};

pub const Kill = packed struct {
    pub fn new() @This() {
        return @This(){};
    }

    pub fn serialize(_: @This(), _: []u8) !usize {
        return 0;
    }

    pub fn deserialize(_: []u8) !@This() {
        return @This(){};
    }
};

test "basic serialization" {
    const cont = Request.new(.{ .cont = Continue.new() });
    const cont_bytes = try cont.serialize(std.testing.allocator);
    defer std.testing.allocator.free(cont_bytes);
    try expect(cont_bytes.len == @sizeOf(u64));

    const br = Request.new(.{ .br = Break.new(0xdeadbeef) });
    try expect(br.id == Request.IDs.Break);
    const br_bytes = try br.serialize(std.testing.allocator);
    defer std.testing.allocator.free(br_bytes);
    try expect(br_bytes.len == @sizeOf(u64) + @sizeOf(u32));
    var answer_bytes = [_]u8{
        0xef, 0xbe, 0xad, 0xde,
    };
    try expect(std.mem.eql(u8, br_bytes[@sizeOf(u64)..], &answer_bytes));
}

const expect = std.testing.expect;
