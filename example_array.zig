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

    var array: [128]u8 = undefined;
    for (&array, 0..) |*e, i| {
        e.* = @intCast(i);
    }

    try tree_formatter.format(array, .{
        .name = "array",
        .array_elem_limit = 5,
        .print_u8_chars = false,
    });
}
