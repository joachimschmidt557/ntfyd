//! Common functionality for ntfy notification delivery methods

const std = @import("std");

const ntfy = @import("ntfy.zig");
const Message = ntfy.Message;

pub const Http = @import("source/Http.zig");

const Source = @This();

tag: Tag,

pub const Tag = enum {
    /// HTTP stream with JSON messages
    http,
};

/// User authentication for topics with access control
pub const Authentication = struct {
    username: []const u8,
    password: []const u8,
};

/// Delivery(HTTP/Websocket/...)-independent description of a single
/// connection to a server
pub const Connection = struct {
    uri: std.Uri,
    topics: []const []const u8,

    authentication: ?Authentication = null,
    filter_id: ?[]const u8 = null,
    filter_message: ?[]const u8 = null,
    filter_title: ?[]const u8 = null,
    filter_priority: ?[]const u32 = null,
    filter_tags: ?[]const []const u8 = null,
};

pub fn deinit(base: *Source) void {
    switch (base.tag) {
        .http => @fieldParentPtr(Http, "base", base).deinit(),
    }
}

pub fn nextMessage(base: *Source) !Message {
    switch (base.tag) {
        .http => return try @fieldParentPtr(Http, "base", base).nextMessage(),
    }
}

pub fn constructUriPath(
    allocator: std.mem.Allocator,
    connection: Connection,
    tag: Tag,
) ![]const u8 {
    const topics_joined = try std.mem.join(allocator, ",", connection.topics);
    defer allocator.free(topics_joined);

    const endpoint = switch (tag) {
        .http => "json",
    };

    const uri_path = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{
        connection.uri.path,
        topics_joined,
        endpoint,
    });
    return uri_path;
}

pub fn constructRequestHeaders(
    allocator: std.mem.Allocator,
    connection: Connection,
) ![]const std.http.CustomHeader {
    var headers = std.ArrayList(std.http.CustomHeader).init(allocator);
    errdefer headers.deinit();

    if (connection.authentication) |auth| {
        const Base64Encoder = std.base64.standard.Encoder;

        const username_password = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ auth.username, auth.password });
        defer allocator.free(username_password);

        const buf = try allocator.alloc(u8, Base64Encoder.calcSize(username_password.len));
        defer allocator.free(buf);
        const base64 = Base64Encoder.encode(buf, username_password);

        const value = try std.fmt.allocPrint(allocator, "Basic {s}", .{base64});
        try headers.append(.{ .name = "Authorization", .value = value });
    }

    return headers.toOwnedSlice();
}

pub fn freeRequestHeaders(
    allocator: std.mem.Allocator,
    headers: []const std.http.CustomHeader,
) void {
    for (headers) |header| {
        allocator.free(header.value);
    }
    allocator.free(headers);
}
