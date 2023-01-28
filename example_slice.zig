const std = @import("std");
const TreeFormatter = @import("./src/tree_fmt.zig").TreeFormatter;

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
    var tree_formatter = TreeFormatter.init(allocator, .{
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });

    var array_list = std.ArrayList(u8).init(allocator);
    defer array_list.deinit();

    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        try array_list.append(i);
    }

    try tree_formatter.formatValueWithId(w, array_list, "array");

    try tree_formatter.formatValueWithId(w, std.mem.span(array_list.items[0..0]), "array");
    try tree_formatter.formatValueWithId(w, std.mem.span(array_list.items[0..1]), "array");
    try tree_formatter.formatValueWithId(w, std.mem.span(array_list.items[0..2]), "array");
}
