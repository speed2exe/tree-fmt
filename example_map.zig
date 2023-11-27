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

    const w = std.io.getStdOut().writer();
    var tree_formatter = treeFormatter(allocator, w);

    var map = std.AutoHashMap(u8, u8).init(allocator);
    defer map.deinit();

    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        try map.put(i, i * 2);
    }

    try tree_formatter.format(map, .{ .name = "map1" });
}
