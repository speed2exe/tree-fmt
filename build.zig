const std = @import("std");

pub fn build(b: *std.Build) void {
    const lib = b.addStaticLibrary(.{
        .name = "tree-fmt",
        .root_source_file = .{ .path = "src/tree_fmt.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/example/anon_struct.zig" },
    });
    const test_step = b.step("test", "tree pretty fmt");
    test_step.dependOn(&main_tests.step);

    lib.install();
}
