const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("tree-fmt", .{
        .source_file = std.Build.FileSource.relative("src/tree_fmt.zig"),
    });
}
