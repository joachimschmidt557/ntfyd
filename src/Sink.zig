const ntfy = @import("ntfy.zig");
const Message = ntfy.Message;

pub const DBus = @import("sink/DBus.zig");

const Sink = @This();

tag: Tag,

pub const Tag = enum {
    dbus,
};

pub fn deinit(base: *Sink) void {
    switch (base.tag) {
        .dbus => @fieldParentPtr(DBus, "base", base).deinit(),
    }
}

pub fn notify(base: *Sink, message: Message) !void {
    switch (base.tag) {
        .dbus => try @fieldParentPtr(DBus, "base", base).notify(message),
    }
}
