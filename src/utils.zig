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
    var label: []const u8 = undefined;

    if (node.tag_name) |tag| {
        label = tag;
    } else if (node.text) |text| {
        label = try std.fmt.allocPrint(allocator, "\"{s}\"", .{text});
    } else if (node.comment) |comment| {
        label = try std.fmt.allocPrint(allocator, "comment: \"{s}\"", .{comment});
    } else {
        label = "Document";
    }

    try writer.print("    {s}[{s}]\n", .{ id, label });

    var child_index: usize = 0;
    for (node.children.items) |child| {
        node_id_counter.* += 1;
        const child_id = try std.fmt.allocPrint(allocator, "n{d}", .{node_id_counter.*});
        try writer.print("    {s} --> {s}\n", .{ id, child_id });
        try printMermaidNode(allocator, writer, child, child_id, node_id_counter);
        child_index += 1;
    }
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
