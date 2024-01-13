const std = @import("std");

pub fn build(b: *std.Build) void {
    // 0.11
    // _ = b.addModule("tree-fmt", .{
    //     .source_file = std.Build.FileSource.relative("src/tree_fmt.zig"),
    // });

    // v0.12.0-dev.2150+63de8a598
    _ = b.addModule("tree-fmt", .{
        .root_source_file = .{ .path = "src/tree_fmt.zig" },
    });
}
