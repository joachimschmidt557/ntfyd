//! Notification sink that does nothing

const std = @import("std");

const ntfy = @import("../ntfy.zig");
const Message = ntfy.Message;
const Sink = @import("../Sink.zig");

const Null = @This();

base: Sink,

pub const base_tag: Sink.Tag = .null;

pub fn create(allocator: std.mem.Allocator) !*Null {
    const result = try allocator.create(Null);
    errdefer allocator.destroy(result);

    result.* = Null{
        .base = .{
            .tag = .null,
            .allocator = allocator,
        },
    };
    return result;
}

pub fn destroy(self: *Null) void {
    const allocator = self.base.allocator;

    allocator.destroy(self);
}

pub fn notify(self: *Null, message: Message) !void {
    _ = self;
    _ = message;
}
