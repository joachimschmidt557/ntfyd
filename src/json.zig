//! Functions to make working with std.json.Value easier

const std = @import("std");

const JsonTagType = @typeInfo(std.json.Value).Union.tag_type.?;

fn JsonType(comptime T: JsonTagType) type {
    switch (T) {
        .Null => return void,
        .Bool => return bool,
        .Integer => return i64,
        .Float => return f64,
        .NumberString => return []const u8,
        .String => return []const u8,
        .Array => return std.json.Array,
        .Object => return std.json.ObjectMap,
    }
}

pub fn jsonObjectGetOrNull(
    comptime T: JsonTagType,
    json_object: std.json.ObjectMap,
    name: []const u8,
) !?JsonType(T) {
    const json_value = json_object.get(name) orelse return null;

    switch (json_value) {
        inline else => |value, tag| {
            if (tag == T) {
                return value;
            } else {
                return error.WrongType;
            }
        },
    }
}

pub fn jsonObjectGet(
    comptime T: JsonTagType,
    json_object: std.json.ObjectMap,
    name: []const u8,
) !JsonType(T) {
    const maybe_value = try jsonObjectGetOrNull(T, json_object, name);
    if (maybe_value) |value| {
        return value;
    } else {
        return error.AttributeNotFound;
    }
}
