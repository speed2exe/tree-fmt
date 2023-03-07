const std = @import("std");

pub fn build(b: *std.Build) void {
    const lib = b.addStaticLibrary(.{
        .name = "tree-fmt",
        .root_source_file = .{ .path = "src/tree_fmt.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    lib.addModule("tree-fmt", b.createModule(.{
        .source_file = .{ .path = "src/tree_fmt.zig" },
    }));
    lib.install();
}
