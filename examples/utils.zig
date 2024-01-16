const std = @import("std");
const tree_fmt = @import("tree-fmt");
const treeFormatter = tree_fmt.treeFormatter;
const TreeFormatter = tree_fmt.TreeFormatter;
pub const formatter = blk: {
    break :blk treeFormatter(std.testing.allocator, std.io.getStdErr().writer());
};
