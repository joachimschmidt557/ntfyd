//! D-Bus desktop notification support

const std = @import("std");

const ntfy = @import("../ntfy.zig");
const Message = ntfy.Message;
const Sink = @import("../Sink.zig");

const c = @cImport({
    @cInclude("systemd/sd-bus.h");
});
const sd_bus_error_null = c.sd_bus_error{ .name = null, .message = null, ._need_free = 0 };

const DBus = @This();

base: Sink,

bus: *c.sd_bus,

pub const base_tag: Sink.Tag = .dbus;

pub fn create(allocator: std.mem.Allocator) !*DBus {
    const dbus = try allocator.create(DBus);
    errdefer allocator.destroy(dbus);

    var maybe_bus: ?*c.sd_bus = null;
    if (c.sd_bus_default_user(&maybe_bus) < 0) {
        return error.DBusConnectError;
    }

    if (maybe_bus) |bus| {
        dbus.* = DBus{
            .base = .{
                .tag = .dbus,
                .allocator = allocator,
            },

            .bus = bus,
        };
        return dbus;
    } else {
        return error.DBusConnectError;
    }
}

pub fn destroy(dbus: *DBus) void {
    const allocator = dbus.base.allocator;

    _ = c.sd_bus_unref(dbus.bus);

    allocator.destroy(dbus);
}

pub fn notify(dbus: *DBus, message: Message) !void {
    const allocator = dbus.base.allocator;

    const message_z = try allocator.dupeZ(u8, message.message.?);
    defer allocator.free(message_z);

    const title_z = if (message.title) |title| try allocator.dupeZ(u8, title) else "ntfy";
    defer if (message.title) |_| allocator.free(title_z);

    var ret_error: c.sd_bus_error = sd_bus_error_null;
    defer c.sd_bus_error_free(&ret_error);

    const app_name = "ntfy";
    const replaces_id = @as(u32, 0);
    const app_icon = "";
    const summary = title_z.ptr;
    const body = message_z.ptr;
    const expire_timeout = @as(i32, -1);
    const result = c.sd_bus_call_method(
        dbus.bus,
        "org.freedesktop.Notifications",
        "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications",
        "Notify",
        &ret_error,
        null,
        "susssasa{sv}i",
        app_name,
        replaces_id,
        app_icon,
        summary,
        body,
        @as(c_int, 0),
        @as(c_int, 0),
        expire_timeout,
    );

    if (result < 0) {
        std.log.err("error sending dbus message: return={} error.name={s} error.message={s}", .{
            result,
            ret_error.name,
            ret_error.message,
        });

        return error.DBusMethodCallError;
    }
}
