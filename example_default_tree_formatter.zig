var tree_formatter = @import("./src/tree_fmt.zig").defaultFormatter();

pub fn main() !void {
    try tree_formatter.formatValueWithId(.{ 1, 2.4, "hi" }, "some_anon_struct");
}
