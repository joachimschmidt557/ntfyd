//! ntfy message decoding

const std = @import("std");

const json = @import("json.zig");

pub const Event = enum {
    open,
    keepalive,
    message,
    poll_request,
};

pub const Message = struct {
    id: []const u8,
    time: u64,
    expires: ?u64 = null,
    event: Event,
    topic: []const u8,
    message: ?[]const u8 = null,
    title: ?[]const u8 = null,
    priority: ?u8 = null,

    pub fn fromJson(json_value: std.json.Value) !Message {
        const root: std.json.ObjectMap = switch (json_value) {
            .object => |x| x,
            else => return error.ExpectedRootObject,
        };

        const id = try json.jsonObjectGet(.string, root, "id");

        const time = time: {
            const raw = try json.jsonObjectGet(.integer, root, "time");
            break :time std.math.cast(u64, raw) orelse return error.InvalidTime;
        };

        const expires = expires: {
            const raw = try json.jsonObjectGetOrNull(.integer, root, "expires") orelse
                break :expires null;
            break :expires std.math.cast(u64, raw) orelse return error.InvalidExpires;
        };

        const event = event: {
            const raw = try json.jsonObjectGet(.string, root, "event");
            break :event std.meta.stringToEnum(Event, raw) orelse return error.InvalidEvent;
        };

        const topic = try json.jsonObjectGet(.string, root, "topic");

        if (event == .message) {
            const message = try json.jsonObjectGet(.string, root, "message");

            const title = try json.jsonObjectGetOrNull(.string, root, "title") orelse "ntfy";

            const priority: ?u8 = priority: {
                const raw = try json.jsonObjectGetOrNull(.integer, root, "priority") orelse
                    break :priority null;

                if (raw >= 1 and raw <= 5) {
                    break :priority @intCast(raw);
                } else {
                    return error.InvalidPriority;
                }
            };

            return Message{
                .id = id,
                .time = time,
                .expires = expires,
                .event = event,
                .topic = topic,
                .message = message,
                .title = title,
                .priority = priority,
            };
        } else {
            return Message{
                .id = id,
                .time = time,
                .expires = expires,
                .event = event,
                .topic = topic,
            };
        }
    }
};
