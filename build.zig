const std = @import("std");

pub fn build(b: *std.Build) void {
    const tree_fmt = b.addModule("tree-fmt", .{
        .root_source_file = .{ .path = "src/tree_fmt.zig" },
    });

    // zig build test
    const examples = b.addTest(.{
        .root_source_file = .{ .path = "./examples/examples.zig" },
    });
    // zig build test -Dtest-filter=...
    examples.filter = b.option([]const u8, "test-filter", "Filter for tests to run");
    const run_examples = b.addRunArtifact(examples);
    const run_examples_step = b.step("test", "Run examples");
    run_examples_step.dependOn(&run_examples.step);
    examples.root_module.addImport("tree-fmt", tree_fmt);
}
