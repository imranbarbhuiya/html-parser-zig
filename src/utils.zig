const std = @import("std");
const ast = @import("ast.zig");

pub fn isWhitespaceOnly(str: []u8) bool {
    return std.mem.trim(u8, str, " \n\r\t").len == 0;
}

pub fn printNodeTree(node: ast.Node, indent: usize) !void {
    const writer = std.io.getStdOut().writer();

    for (0..indent) |_| {
        _ = try writer.print("  ", .{});
    }

    if (node.comment) |comment| {
        _ = try writer.print("{s}\n", .{comment});
        return;
    }

    if (node.text) |txt| {
        _ = try writer.print("{s}\n", .{txt});
        return;
    }

    if (node.tag_name) |tag| {
        _ = try writer.print("<{s}", .{tag});
        for (node.attributes.items) |attr| {
            if (attr.value) |val| {
                _ = try writer.print(" {s}=\"{s}\"", .{ attr.name, val });
            } else {
                _ = try writer.print(" {s}", .{attr.name});
            }
        }

        if (isVoidElement(tag)) {
            _ = try writer.print(" />\n", .{});
            return;
        } else {
            _ = try writer.print(">\n", .{});
        }
    }

    for (node.children.items) |child| {
        try printNodeTree(child, indent + 1);
    }

    if (node.tag_name) |tag| {
        for (0..indent) |_| {
            _ = try writer.print("  ", .{});
        }
        _ = try writer.print("</{s}>\n", .{tag});
    }
}

// These print functions are written using AI so don't ask me anything about it 😄.
pub fn writeNodeTreeMarkdownMermaidToFile(allocator: std.mem.Allocator, root: ast.Node) !void {
    const dir_path = "html";
    const file_path = "html/output.md";

    try std.fs.cwd().makePath(dir_path);

    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    _ = try writer.print("```mermaid\n", .{});
    _ = try writer.print("graph TD\n", .{});

    var node_id_counter: usize = 0;
    try printMermaidNode(allocator, writer, root, "n0", &node_id_counter);

    _ = try writer.print("```\n", .{});
}

fn printMermaidNode(
    allocator: std.mem.Allocator,
    writer: anytype,
    node: ast.Node,
    id: []const u8,
    node_id_counter: *usize,
) !void {
    const safeLabel = try makeSafeLabel(allocator, node);

    try writer.print("    {s}[{s}]\n", .{ id, safeLabel });

    for (node.children.items) |child| {
        node_id_counter.* += 1;
        const child_id = try std.fmt.allocPrint(allocator, "n{d}", .{node_id_counter.*});
        try writer.print("    {s} --> {s}\n", .{ id, child_id });
        try printMermaidNode(allocator, writer, child, child_id, node_id_counter);
    }
}

pub fn writeAstToJson(allocator: std.mem.Allocator, root: ast.Node) !void {
    const dir_path = "html";
    const file_path = "html/output.json";

    try std.fs.cwd().makePath(dir_path);

    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    try writeNodeAsJson(allocator, writer, root, 0);
}

fn writeNodeAsJson(
    allocator: std.mem.Allocator,
    writer: anytype,
    node: ast.Node,
    indent: usize,
) !void {
    const ind = try indentString(allocator, indent);
    try writer.print("{s}{{\n", .{ind});

    var has_previous = false;

    if (node.tag_name) |tag| {
        try writer.print("{s}  \"tag\": ", .{ind});
        try std.json.stringify(tag, .{}, writer);
        has_previous = true;
    }

    if (node.attributes.items.len > 0) {
        if (has_previous) try writer.print(",\n", .{});
        try writer.print("{s}  \"attributes\": {{\n", .{ind});
        for (node.attributes.items, 0..) |attr, i| {
            const comma = if (i < node.attributes.items.len - 1) "," else "";

            try writer.print("{s}    ", .{ind});
            try std.json.stringify(attr.name, .{}, writer);
            try writer.print(": ", .{});

            if (attr.value) |val| {
                try std.json.stringify(val, .{}, writer);
            } else {
                try writer.print("true", .{});
            }

            try writer.print("{s}\n", .{comma});
        }
        try writer.print("{s}  }}", .{ind});
        has_previous = true;
    }

    if (node.text) |txt| {
        if (has_previous) try writer.print(",\n", .{});
        try writer.print("{s}  \"text\": ", .{ind});
        try std.json.stringify(txt, .{}, writer);
        has_previous = true;
    }

    if (node.comment) |comment| {
        if (has_previous) try writer.print(",\n", .{});
        try writer.print("{s}  \"comment\": ", .{ind});
        try std.json.stringify(comment, .{}, writer);
        has_previous = true;
    }

    if (node.children.items.len > 0) {
        if (has_previous) try writer.print(",\n", .{});
        try writer.print("{s}  \"children\": [\n", .{ind});
        for (node.children.items, 0..) |child, i| {
            try writeNodeAsJson(allocator, writer, child, indent + 2);
            if (i < node.children.items.len - 1) {
                try writer.print(",\n", .{});
            } else {
                try writer.print("\n", .{});
            }
        }
        try writer.print("{s}  ]", .{ind});
    }

    try writer.print("\n{s}}}", .{ind});
}

const void_elements = [_][]const u8{
    "area",  "base",   "br",    "col",  "embed",
    "hr",    "img",    "input", "link", "meta",
    "param", "source", "track", "wbr",
};

pub fn isVoidElement(name: []const u8) bool {
    for (void_elements) |v| {
        if (std.ascii.eqlIgnoreCase(name, v)) return true;
    }
    return false;
}

fn indentString(allocator: std.mem.Allocator, level: usize) ![]u8 {
    const total = level * 2; // "  " per level
    const buf = try allocator.alloc(u8, total);
    for (buf) |*c| c.* = ' ';
    return buf;
}

fn makeSafeLabel(allocator: std.mem.Allocator, node: ast.Node) ![]const u8 {
    if (node.tag_name) |tag| {
        return tag;
    } else if (node.text) |text| {
        return try formatSafe(allocator, .text, text);
    } else if (node.comment) |comment| {
        return try formatSafe(allocator, .comment, comment);
    }
    return "Document";
}

fn formatSafe(allocator: std.mem.Allocator, kind: enum { text, comment }, value: []const u8) ![]const u8 {
    const cleaned = try cleanMermaidText(allocator, value);

    return switch (kind) {
        .text => std.fmt.allocPrint(allocator, "text: {s}", .{cleaned}),
        .comment => std.fmt.allocPrint(allocator, "comment: {s}", .{cleaned}),
    };
}

fn cleanMermaidText(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    var count: usize = 0;
    for (input) |c| {
        if (count >= 40) {
            try buf.appendSlice("…");
            break;
        }

        switch (c) {
            '\n', '\r' => try buf.append(' '),
            '[', ']', '{', '}', '(', ')', ':', '=', '%', '.', '\"', '\'', '`', '\\', '>', '<', '|', '&' => {}, // skip
            else => try buf.append(c),
        }

        count += 1;
    }

    return try allocator.dupe(u8, buf.items);
}
