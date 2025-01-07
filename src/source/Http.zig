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
parsed_json: ?std.json.Parsed(std.json.Value) = null,

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
        .path = .{.raw = uri_path},
        .query = connection.uri.query,
        .fragment = connection.uri.fragment,
    };

    const headers = try Source.constructRequestHeaders(allocator, connection);

    var server_header_buffer: [16 * 1024]u8 = undefined;
    var request = try http_client.open(.GET, uri, .{
        .server_header_buffer = &server_header_buffer,
        .headers = headers,
    });
    errdefer request.deinit();

    try request.send();
    try request.finish();
    try request.wait();

    switch (request.response.status) {
        .ok => return request,
        else => {
            std.log.err("connection returned response {}", .{request.response.status});
            return error.HttpConnectError;
        },
    }
}

fn clearBuffers(http: *Http) void {
    http.buf.clearAndFree(http.allocator);
    if (http.parsed_json) |*parsed| {
        parsed.deinit();
        http.parsed_json = null;
    }
}

pub fn deinit(http: *Http) void {
    const allocator = http.allocator;

    http.request.deinit();
    http.clearBuffers();

    allocator.destroy(http);
}

pub fn nextMessage(http: *Http) !ntfy.Message {
    messages: while (true) {
        http.clearBuffers();

        var json_scanner = std.json.Scanner.initStreaming(http.allocator);
        defer json_scanner.deinit();

        var buffer: [std.json.default_buffer_size]u8 = undefined;

        read: while (true) {
            json_scanner.skipUntilStackHeight(0) catch |err| switch (err) {
                error.BufferUnderrun => {
                    // FIXME put a buffered reader in fromt of http.request.reader() and
                    // read byte by byte
                    //
                    // in case two messages are read at once into the buffer, this would
                    // save the second message from being ignored
                    const input = buffer[0..try http.request.reader().read(&buffer)];
                    json_scanner.feedInput(input);

                    try http.buf.appendSlice(http.allocator, input);

                    continue :read;
                },
                else => return err,
            };

            break :read;
        }

        http.parsed_json = std.json.parseFromSlice(std.json.Value, http.allocator, http.buf.items, .{}) catch |err| {
            std.log.warn("error parsing JSON message: {}", .{err});
            continue :messages;
        };

        const message = ntfy.Message.fromJson(http.parsed_json.?.value) catch |err| {
            std.log.warn("error decoding JSON message: {}", .{err});
            continue :messages;
        };

        if (message.event == .message) {
            std.log.debug("received message: {s}", .{message.message.?});
            return message;
        }
    }
}
