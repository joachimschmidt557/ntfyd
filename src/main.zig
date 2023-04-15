const std = @import("std");

const Source = @import("Source.zig");
const Http = Source.Http;

const Sink = @import("Sink.zig");
const DBus = Sink.DBus;

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var server_address: ?[]const u8 = null;
    var topics = std.ArrayList([]const u8).init(allocator);
    defer topics.deinit();
    var username: ?[]const u8 = null;
    var password: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, "-u", args[i])) {
            if (i + 1 >= args.len) fatal("expected parameter after '{s}'", .{arg});
            i += 1;
            username = args[i];
        } else if (std.mem.eql(u8, "-p", args[i])) {
            if (i + 1 >= args.len) fatal("expected parameter after '{s}'", .{arg});
            i += 1;
            password = args[i];
        } else if (server_address == null) {
            server_address = arg;
        } else {
            try topics.append(arg);
        }
    }

    if (server_address == null) fatal("no server address provided", .{});
    if (topics.items.len < 1) fatal("no topics provided", .{});
    if (username != null and password == null) fatal("username provided, but no password provided", .{});
    if (username == null and password != null) fatal("password provided, but no username provided", .{});

    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();

    const sink = &(try DBus.init(allocator)).base;
    defer sink.deinit();

    const source = &(try Http.init(allocator, .{
        .uri = try std.Uri.parse(server_address.?),
        .topics = topics.items,
        .authentication = if (username) |_| .{ .username = username.?, .password = password.? } else null,
    }, &http_client)).base;
    defer source.deinit();

    messages: while (true) {
        const message = try source.nextMessage();

        sink.notify(message) catch |err| {
            std.log.warn("error sending notification: {}", .{err});
            continue :messages;
        };
    }
}
