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

    const sentinel_array: [*:0]const u8 = "hello world";

    try tree_formatter.format(sentinel_array, .{ .name = "sentinel_array" });
}
