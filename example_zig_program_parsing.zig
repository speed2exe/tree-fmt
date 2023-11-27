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

    var ast = try std.zig.Ast.parse(allocator, zig_code, .zig);
    defer ast.deinit(allocator);
    try tree_formatter.format(ast.tokens, .{ .name = "ast" });
}

const zig_code =
    \\ const std = @import("std");
    \\
    \\ pub fn main() void {
    \\     std.debug.print("hello {s}", .{"world"});
    \\ }
;
