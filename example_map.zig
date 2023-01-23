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
    var tree_formatter = TreeFormatter.init(allocator, .{});

    var map = std.AutoHashMap(u8, u8).init(allocator);
    defer map.deinit();

    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        try map.put(i, i * 2);
    }

    try tree_formatter.formatValueWithId(w, map, "map");
}
