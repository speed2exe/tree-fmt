var tree_formatter = @import("./src/tree_fmt.zig").defaultFormatter();

pub fn main() !void {
    try tree_formatter.format(
        .{ 1, 2.4, .{ .name = "hi" } }, // your data
        .{ .name = "some_anon_struct" }, // settings
    );
}
