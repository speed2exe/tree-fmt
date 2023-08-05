const std = @import("std");
const treeFormatter = @import("./src/tree_fmt.zig").treeFormatter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .ok => {},
            .leak => std.log.err("memory leak detected", .{}),
        }
    }

    var w = std.io.getStdOut().writer();
    var tree_formatter = treeFormatter(allocator, w);

    var array_list = std.ArrayList(u8).init(allocator);
    defer array_list.deinit();

    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        try array_list.append(i);
    }

    try tree_formatter.format(array_list, .{ .name = "array" });
    try tree_formatter.format(array_list.items[0..0], .{
        .name = "slice1",
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });
    try tree_formatter.format(array_list.items[0..1], .{
        .name = "slice2",
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });
    try tree_formatter.format(array_list.items[0..2], .{
        .name = "slice3",
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });
}
