const std = @import("std");
const build_options = @import("build_options");

const ntfy = @import("ntfy.zig");
const Message = ntfy.Message;

pub const Null = @import("sink/Null.zig");
pub const DBus = @import("sink/DBus.zig");

const Sink = @This();

tag: Tag,
allocator: std.mem.Allocator,

pub const Tag = enum {
    null,
    dbus,
};

/// List of sinks enabled in the build options, in order of preference
/// (most preferred first)
///
/// Guaranteed to be non-empty as the null sink is always supported
pub const supported_sinks = blk: {
    var result: []const Sink.Tag = &.{};

    if (build_options.enable_dbus) {
        result = result ++ &[_]Sink.Tag{.dbus};
    }

    result = result ++ .{.null};

    break :blk result;
};

pub fn create(allocator: std.mem.Allocator, tag: Tag) !*Sink {
    switch (tag) {
        .null => return &(try Null.create(allocator)).base,
        .dbus => if (build_options.enable_dbus) {
            return &(try DBus.create(allocator)).base;
        } else unreachable,
    }
}

pub fn destroy(base: *Sink) void {
    switch (base.tag) {
        .null => @fieldParentPtr(Null, "base", base).destroy(),
        .dbus => if (build_options.enable_dbus) {
            @fieldParentPtr(DBus, "base", base).destroy();
        } else unreachable,
    }
}

pub fn notify(base: *Sink, message: Message) !void {
    switch (base.tag) {
        .null => try @fieldParentPtr(Null, "base", base).notify(message),
        .dbus => if (build_options.enable_dbus) {
            try @fieldParentPtr(DBus, "base", base).notify(message);
        } else unreachable,
    }
}
