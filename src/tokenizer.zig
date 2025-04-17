const std = @import("std");
const Token = @import("token.zig").Token;
const utils = @import("utils.zig");

pub fn tokenize(allocator: std.mem.Allocator, buffer: []u8) ![]Token {
    var list = std.ArrayList(Token).init(allocator);

    var i: usize = 0;

    while (i < buffer.len) {
        if (buffer[i] == '<') {
            const start = i;

            if (i + 3 < buffer.len and std.mem.eql(u8, buffer[i .. i + 4], "<!--")) {
                i += 4;
                while (i + 2 < buffer.len and !std.mem.eql(u8, buffer[i .. i + 3], "-->")) : (i += 1) {}
                if (i + 2 < buffer.len) i += 3;

                const comment_slice = buffer[start..i];
                try list.append(Token{ .comment = comment_slice });
                continue;
            }

            while (i < buffer.len and buffer[i] != '>') : (i += 1) {}
            if (i < buffer.len and buffer[i] == '>') {
                i += 1;
            }

            const tag_slice = buffer[start..i];

            const trimmed = std.mem.trim(u8, tag_slice, " \n\r\t");

            if (std.mem.startsWith(u8, trimmed, "<!")) {
                try list.append(Token{ .declaration = tag_slice });
            } else if (std.mem.startsWith(u8, trimmed, "</")) {
                try list.append(Token{ .close_tag = tag_slice });
            } else if (std.mem.endsWith(u8, trimmed, "/>")) {
                try list.append(Token{ .self_closing_tag = tag_slice });
            } else {
                try list.append(Token{ .open_tag = tag_slice });

                if (tag_slice.len >= 7 and std.ascii.eqlIgnoreCase(tag_slice[0..7], "<script")) {
                    const script_start = i;
                    while (i + 8 < buffer.len and !std.ascii.eqlIgnoreCase(buffer[i .. i + 9], "</script>")) : (i += 1) {}

                    if (i + 8 < buffer.len) {
                        const script_content = buffer[script_start..i];
                        try list.append(Token{ .text = script_content });

                        const close_start = i;
                        i += 9;
                        try list.append(Token{ .close_tag = buffer[close_start..i] });
                    }
                }
            }
        } else {
            const start = i;

            while (i < buffer.len and buffer[i] != '<') : (i += 1) {}

            const slice = buffer[start..i];
            if (!utils.isWhitespaceOnly(slice)) {
                try list.append(Token{ .text = slice });
            }
        }
    }

    return list.toOwnedSlice();
}
