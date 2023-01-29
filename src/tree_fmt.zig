const std = @import("std");
const tree_formatter = @import("./tree_formatter.zig");
pub const treeFormatter = tree_formatter.treeFormatter;
pub const TreeFormatter = tree_formatter.TreeFormatter;
pub const TreeFormatterSettings = @import("./tree_formatter_settings.zig").TreeFormatterSettings;

// Create a TreeFormatter with:
// - default settings from TreeFormatterSettings
// - std.heap.page_allocator as the allocator
// - std.io.getStdOut().writer() as the writer
pub fn defaultFormatter() TreeFormatter(@TypeOf(std.io.getStdOut().writer())) {
    return treeFormatter(std.heap.page_allocator, std.io.getStdOut().writer(), .{});
}
