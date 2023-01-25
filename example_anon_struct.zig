const std = @import("std");
const TreeFormatter = @import("./src/tree_fmt.zig").TreeFormatter;

pub fn main() !void {
    var w = std.io.getStdOut().writer();
    var tree_printer = TreeFormatter.init(std.heap.page_allocator, .{});
    try tree_printer.formatValueWithId(w, .{ 1, 2, 3 }, "tuple");

    const s = .{ .a = "hello", .b = @as(i32, 5), .c = 3, .d = 3.14 };
    try tree_printer.formatValueWithId(w, s, "s");
}
