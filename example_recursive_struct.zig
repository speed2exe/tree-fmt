const std = @import("std");
const TreeFormatter = @import("./src/tree_formatter.zig").TreeFormatter;
const TreeFormtterSettings = @import("./src/tree_formatter.zig").TreeFormatterSettings;

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
    var tree_formatter = TreeFormatter.init(allocator, TreeFormtterSettings{
        .ptr_repeat_limit = 2,
    });

    var n1 = LinkedNode{ .val = 1 };
    var n2 = LinkedNode{ .val = 2 };
    n1.next = &n2;
    n2.next = &n1;

    try tree_formatter.formatValueWithId(w, n1, "n1");
}
