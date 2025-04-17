const std = @import("std");
const Token = @import("token.zig").Token;
const ast = @import("ast.zig");
const utils = @import("utils.zig");

pub const Document = struct {
    doctype: ?[]u8,
    root: ast.Node,
};

pub fn parseTokens(allocator: std.mem.Allocator, tokens: []Token) !Document {
    var stack = std.ArrayList(*ast.Node).init(allocator);
    defer stack.deinit();

    var root = ast.Node{
        .tag_name = null,
        .attributes = std.ArrayList(ast.Attribute).init(allocator),
        .children = std.ArrayList(ast.Node).init(allocator),
        .text = null,
        .comment = null,
    };

    var i: usize = 0;
    var doctype: ?[]u8 = null;

    while (i < tokens.len) {
        const token = tokens[i];
        i += 1;

        switch (token) {
            .declaration => |val| {
                if (doctype == null) {
                    doctype = val;
                }
            },
            .comment => |val| {
                const node = try makeCommentNode(allocator, val);
                try getCurrentParent(&stack, &root).children.append(node.*);
            },
            .text => |val| {
                const node = try makeTextNode(allocator, val);
                try getCurrentParent(&stack, &root).children.append(node.*);
            },
            .open_tag => |val| {
                const elem = try makeElementNode(allocator, val);

                if (elem.tag_name) |tag| {
                    if (utils.isVoidElement(tag)) {
                        try getCurrentParent(&stack, &root).children.append(elem);
                    } else {
                        const node_ptr = try allocator.create(ast.Node);
                        node_ptr.* = elem;
                        try stack.append(node_ptr);
                    }
                }
            },
            .self_closing_tag => |val| {
                const node_ptr = try allocator.create(ast.Node);
                node_ptr.* = try makeElementNode(allocator, val);
                try getCurrentParent(&stack, &root).children.append(node_ptr.*);
            },
            .close_tag => |val| {
                if (stack.items.len == 0) continue;

                var tag_name: []const u8 = val[2..];
                if (tag_name[tag_name.len - 1] == '>') {
                    tag_name = tag_name[0 .. tag_name.len - 1];
                }
                tag_name = std.mem.trim(u8, tag_name, " \n\r\t");

                const top = stack.items[stack.items.len - 1];
                if (top.tag_name) |open_name| {
                    if (std.ascii.eqlIgnoreCase(open_name, tag_name)) {
                        const node_ptr = stack.pop().?;
                        try getCurrentParent(&stack, &root).children.append(node_ptr.*);
                    } else {
                        std.debug.print("Mismatched close tag: expected </{s}>, got </{s}>\n", .{ open_name, tag_name });
                    }
                }
            },
        }
    }

    return Document{
        .doctype = doctype,
        .root = root,
    };
}

fn makeTextNode(allocator: std.mem.Allocator, text: []u8) !*ast.Node {
    const node_ptr = try allocator.create(ast.Node);
    node_ptr.* = ast.Node{
        .tag_name = null,
        .attributes = std.ArrayList(ast.Attribute).init(allocator),
        .children = std.ArrayList(ast.Node).init(allocator),
        .text = text,
        .comment = null,
    };
    return node_ptr;
}

fn makeCommentNode(allocator: std.mem.Allocator, comment: []u8) !*ast.Node {
    const node_ptr = try allocator.create(ast.Node);
    node_ptr.* = ast.Node{
        .tag_name = null,
        .attributes = std.ArrayList(ast.Attribute).init(allocator),
        .children = std.ArrayList(ast.Node).init(allocator),
        .text = null,
        .comment = comment,
    };
    return node_ptr;
}

fn makeElementNode(allocator: std.mem.Allocator, raw: []u8) !ast.Node {
    var end_index = raw.len;
    if (raw[raw.len - 1] == '>') {
        end_index -= 1;
    }

    var slice: []const u8 = raw[1..end_index];

    slice = std.mem.trim(u8, slice, " \n\r\t/");

    var i: usize = 0;
    while (i < slice.len and !std.ascii.isWhitespace(slice[i])) : (i += 1) {}
    const tag_name = slice[0..i];

    var attrs = std.ArrayList(ast.Attribute).init(allocator);

    while (i < slice.len) {
        while (i < slice.len and std.ascii.isWhitespace(slice[i])) : (i += 1) {}
        if (i >= slice.len) break;

        const name_start = i;
        while (i < slice.len and slice[i] != '=' and !std.ascii.isWhitespace(slice[i])) : (i += 1) {}
        const name = slice[name_start..i];

        while (i < slice.len and std.ascii.isWhitespace(slice[i])) : (i += 1) {}

        var value: ?[]const u8 = null;
        if (i < slice.len and slice[i] == '=') {
            i += 1;
            while (i < slice.len and std.ascii.isWhitespace(slice[i])) : (i += 1) {}

            if (i < slice.len and (slice[i] == '"' or slice[i] == '\'')) {
                const quote = slice[i];
                i += 1;
                const vstart = i;
                while (i < slice.len and slice[i] != quote) : (i += 1) {}
                value = slice[vstart..i];
                if (i < slice.len) i += 1;
            } else {
                const vstart = i;
                while (i < slice.len and !std.ascii.isWhitespace(slice[i])) : (i += 1) {}
                value = slice[vstart..i];
            }
        }

        try attrs.append(ast.Attribute{
            .name = name,
            .value = value,
        });
    }

    return ast.Node{
        .tag_name = tag_name,
        .attributes = attrs,
        .children = try std.ArrayList(ast.Node).initCapacity(allocator, 4),
        .text = null,
        .comment = null,
    };
}

fn getCurrentParent(stack: *std.ArrayList(*ast.Node), root: *ast.Node) *ast.Node {
    if (stack.items.len == 0) {
        return root;
    }
    return stack.items[stack.items.len - 1];
}
