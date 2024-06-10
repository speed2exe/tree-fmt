const std = @import("std");
const tree_formatter = @import("./tree-formatter.zig");
pub const treeFormatter = tree_formatter.treeFormatter;
pub const TreeFormatter = tree_formatter.TreeFormatter;
pub const TreeFormatterSettings = @import("./tree-formatter-settings.zig").TreeFormatterSettings;

// Create a TreeFormatter with:
// - default settings from TreeFormatterSettings
// - use gpa as the allocator
// - std.io.getStdErr().writer() as the writer
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
pub fn defaultFormatter() TreeFormatter(@TypeOf(std.io.getStdErr().writer())) {
    return treeFormatter(allocator, std.io.getStdErr().writer());
}
