const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const utils = @import("utils.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const path = "html/test.html";

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);

    const tokens = try tokenizer.tokenize(allocator, buffer);
    defer allocator.free(tokens);

    // for (tokens) |tok| {
    //     switch (tok) {
    //         .open_tag => |val| try std.io.getStdOut().writer().print("Open: {s}\n", .{val}),
    //         .close_tag => |val| try std.io.getStdOut().writer().print("Close: {s}\n", .{val}),
    //         .self_closing_tag => |val| try std.io.getStdOut().writer().print("Self-closing: {s}\n", .{val}),
    //         .text => |val| try std.io.getStdOut().writer().print("Text: {s}\n", .{val}),
    //         .comment => |val| try std.io.getStdOut().writer().print("Comment: {s}\n", .{val}),
    //         .declaration => |val| try std.io.getStdOut().writer().print("Declaration: {s}\n", .{val}),
    //     }
    // }

    const document = try parser.parseTokens(allocator, tokens);

    const stdout = std.io.getStdOut().writer();

    if (document.doctype) |dt| {
        try stdout.print("DOCTYPE: {s}\n", .{dt});
    }

    try stdout.print("\nParsed HTML Tree:\n", .{});
    try utils.printNodeTree(document.root, 0);
    try utils.writeNodeTreeMarkdownMermaidToFile(allocator, document.root);
    try utils.writeAstToJson(allocator, document.root);
}
