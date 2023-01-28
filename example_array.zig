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
        .array_elem_limit = 5,
        .print_u8_chars = false,
    });

    var array: [128]u8 = undefined;
    for (array) |*e, i| {
        e.* = @intCast(u8, i);
    }

    try tree_formatter.formatValueWithId(w, array, "array");
}
