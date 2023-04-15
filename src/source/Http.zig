//! ntfy notification delivery using HTTP streams with JSON messages

const std = @import("std");

const ntfy = @import("../ntfy.zig");
const Source = @import("../Source.zig");

const Http = @This();

base: Source,

allocator: std.mem.Allocator,
connection: Source.Connection,
http_client: *std.http.Client,

request: std.http.Client.Request,
buf: std.ArrayListUnmanaged(u8) = .{},
json_value: ?std.json.ValueTree = null,

pub const base_tag: Source.Tag = .http;

pub fn init(
    allocator: std.mem.Allocator,
    connection: Source.Connection,
    http_client: *std.http.Client,
) !*Http {
    const http = try allocator.create(Http);
    errdefer allocator.destroy(http);

    http.* = .{
        .base = .{ .tag = .http },

        .allocator = allocator,
        .connection = connection,
        .http_client = http_client,

        .request = try connect(allocator, connection, http_client),
    };

    return http;
}

fn connect(
    allocator: std.mem.Allocator,
    connection: Source.Connection,
    http_client: *std.http.Client,
) !std.http.Client.Request {
    const uri_path = try Source.constructUriPath(allocator, connection, .http);
    defer allocator.free(uri_path);

    // purposefully strip out user and password components
    const uri: std.Uri = .{
        .scheme = connection.uri.scheme,
        .user = null,
        .password = null,
        .host = connection.uri.host,
        .port = connection.uri.port,
        .path = uri_path,
        .query = connection.uri.query,
        .fragment = connection.uri.fragment,
    };

    const custom_headers = try Source.constructRequestHeaders(allocator, connection);
    defer Source.freeRequestHeaders(allocator, custom_headers);

    const headers: std.http.Client.Request.Headers = .{ .custom = custom_headers };
    var request = try http_client.request(uri, headers, .{});
    errdefer request.deinit();

    try request.do();

    if (request.response.headers.status != .ok) {
        return error.HttpConnectError;
    }

    return request;
}

fn clearBuffers(http: *Http) void {
    http.buf.clearAndFree(http.allocator);
    if (http.json_value) |*vt| {
        vt.deinit();
        http.json_value = null;
    }
}

pub fn deinit(http: *Http) void {
    const allocator = http.allocator;

    http.request.deinit();
    http.clearBuffers();

    allocator.destroy(http);
}

pub fn nextMessage(http: *Http) !ntfy.Message {
    http.clearBuffers();

    var json_streaming_parser = std.json.StreamingParser.init();

    read: while (true) {
        const c = try http.request.reader().readByte();
        try http.buf.append(http.allocator, c);

        var token1: ?std.json.Token = undefined;
        var token2: ?std.json.Token = undefined;
        try json_streaming_parser.feed(c, &token1, &token2);
        if (json_streaming_parser.complete) {
            // We want to avoid as much copying as possible. To
            // achieve that, we
            //
            // a) don't copy strings (unless they are escaped) from
            // raw buffer -> JSON
            //
            // b) don't copy strings from JSON -> ntfy.Message
            //
            // This means our data is allocated in two places: the raw
            // buffer and the JSON value (when strings are
            // escaped). In case we return a Message, preserve these
            // two sources, else clear them before reading the next
            // JSON item. The next call to nextMessage will clear the
            // two sources.
            var complete_message = false;
            defer if (!complete_message) {
                http.clearBuffers();

                json_streaming_parser.reset();
            };

            std.log.debug("received JSON: {s}", .{http.buf.items});

            var json_parser = std.json.Parser.init(http.allocator, false);
            defer json_parser.deinit();

            http.json_value = json_parser.parse(http.buf.items) catch |err| {
                std.log.warn("error parsing JSON message: {}", .{err});
                continue :read;
            };

            const message = ntfy.Message.fromJson(http.json_value.?.root) catch |err| {
                std.log.warn("error decoding JSON message: {}", .{err});
                continue :read;
            };

            if (message.event == .message) {
                std.log.debug("received message: {s}", .{message.message.?});
                complete_message = true;
                return message;
            }
        }
    }
}
