const std = @import("std");
const treeFormatter = @import("./src/tree_fmt.zig").treeFormatter;

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
    var tree_formatter = treeFormatter(allocator, w, .{});

    var ast = try std.zig.parse(allocator, zig_code);
    defer ast.deinit(allocator);
    try tree_formatter.formatValueWithId(ast.tokens, "ast");
}

const zig_code =
    \\ const std = @import("std");
    \\
    \\ pub fn main() void {
    \\     std.debug.print("hello {s}", .{"world"});
    \\ }
;
