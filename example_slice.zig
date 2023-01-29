const std = @import("std");
const treeFormatter = @import("./src/tree_fmt.zig").treeFormatter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            @panic("leaked memory!");
        }
    }

    var w = std.io.getStdOut().writer();
    var tree_formatter = treeFormatter(allocator, w, .{
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });

    var array_list = std.ArrayList(u8).init(allocator);
    defer array_list.deinit();

    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        try array_list.append(i);
    }

    try tree_formatter.formatValueWithId(array_list, "array");
    try tree_formatter.formatValueWithId(std.mem.span(array_list.items[0..0]), "slice");
    try tree_formatter.formatValueWithId(std.mem.span(array_list.items[0..1]), "slice");
    try tree_formatter.formatValueWithId(std.mem.span(array_list.items[0..2]), "slice");
}
