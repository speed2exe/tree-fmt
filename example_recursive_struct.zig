const std = @import("std");
const treeFormatter = @import("./src/tree_fmt.zig").treeFormatter;

const LinkedNode = struct {
    val: i32,
    next: ?*LinkedNode = null,
};

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
    var tree_formatter = treeFormatter(allocator, w, .{
        .ptr_repeat_limit = 2,
    });

    var n1 = LinkedNode{ .val = 1 };
    var n2 = LinkedNode{ .val = 2 };
    n1.next = &n2;
    n2.next = &n1;

    try tree_formatter.formatValueWithId(n1, "n1");
}
