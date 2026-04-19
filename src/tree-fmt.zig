const std = @import("std");
const tree_formatter = @import("./tree-formatter.zig");
pub const treeFormatter = tree_formatter.treeFormatter;
pub const TreeFormatter = tree_formatter.TreeFormatter;
pub const TreeFormatterSettings = @import("./tree-formatter-settings.zig").TreeFormatterSettings;

// A simple writer that forwards to std.debug.print (writes to stderr).
const DebugWriter = struct {
    pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
        _ = self;
        std.debug.print(fmt, args);
    }
    pub fn writeAll(self: @This(), bytes: []const u8) !void {
        _ = self;
        std.debug.print("{s}", .{bytes});
    }
};

// Create a TreeFormatter with:
// - default settings from TreeFormatterSettings
// - use page_allocator as the allocator
// - writes to stderr via std.debug.print
pub fn defaultFormatter() TreeFormatter(DebugWriter) {
    return treeFormatter(std.heap.page_allocator, DebugWriter{});
}
