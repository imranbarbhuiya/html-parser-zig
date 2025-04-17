pub const Token = union(enum) {
    open_tag: []u8, // for <div>
    close_tag: []u8, // for </div>
    self_closing_tag: []u8, // for <img />
    text: []u8, // for text nodes
    declaration: []u8, // for <!DOCTYPE html> or similar
    comment: []u8, // for <!-- comment -->
};
