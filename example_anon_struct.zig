const std = @import("std");
const treeFormatter = @import("./src/tree_fmt.zig").treeFormatter;

pub fn main() !void {
    var w = std.io.getStdOut().writer();
    var tree_formatter = treeFormatter(std.heap.page_allocator, w);
    try tree_formatter.format(.{ 1, 2, 3 }, .{
        .name = "foo",
    });

    const s = .{ .a = "hello", .b = @as(i32, 5), .c = 3, .d = 3.14 };
    try tree_formatter.format(s, .{});
}
