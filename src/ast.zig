const std = @import("std");

pub const Node = struct {
    tag_name: ?[]const u8,
    attributes: std.ArrayList(Attribute),
    children: std.ArrayList(Node),
    text: ?[]const u8,
    comment: ?[]const u8,
};

pub const Attribute = struct {
    name: []const u8,
    value: ?[]const u8,
};
