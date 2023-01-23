const std = @import("std");
const TreeFormatter = @import("./src/tree_formatter.zig").TreeFormatter;
const TreeFormatterSettings = @import("./src/tree_formatter.zig").TreeFormatterSettings;

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
    var tree_formatter = TreeFormatter.init(allocator, TreeFormatterSettings{
        .array_print_limit = 7,
        .print_u8_chars = false,
    });

    var array_list = std.ArrayList(u8).init(allocator);
    defer array_list.deinit();

    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        try array_list.append(i);
    }

    try tree_formatter.formatValueWithId(w, array_list, "array");
}
